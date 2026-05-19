-- ============================================
-- File: 000033_incident_facility_fields.sql
-- ============================================
-- Replaces the single incident facility_id with referral-aware fields:
--   * pickup_location          - enum: whether the patient is collected from a
--                                COMMUNITY or a FACILITY
--   * receiving_facility_id    - destination facility the patient is taken to
--   * referring_facility_id    - facility that referred/originated the case
-- Existing facility_id values are migrated into referring_facility_id.
-- Also adds patient_details_diagnosis for the clinical diagnosis notes.
--
-- vw_incident_summary, mv_incident_daily_stats and mv_dashboard_daily_summary
-- depend on incidents.facility_id, so they are dropped and recreated against
-- referring_facility_id (preserving their output column names).

-- +goose Up
-- +goose StatementBegin
DROP MATERIALIZED VIEW IF EXISTS mv_dashboard_daily_summary;
-- +goose StatementEnd
-- +goose StatementBegin
DROP MATERIALIZED VIEW IF EXISTS mv_incident_daily_stats;
-- +goose StatementEnd
-- +goose StatementBegin
DROP VIEW IF EXISTS vw_incident_summary;
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE incidents ADD COLUMN pickup_location TEXT
    CHECK (pickup_location IS NULL OR pickup_location IN ('COMMUNITY', 'FACILITY'));
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE incidents ADD COLUMN receiving_facility_id UUID REFERENCES ref_facilities(id);
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE incidents ADD COLUMN referring_facility_id UUID REFERENCES ref_facilities(id);
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE incidents ADD COLUMN patient_details_diagnosis TEXT;
-- +goose StatementEnd
-- +goose StatementBegin
UPDATE incidents SET referring_facility_id = facility_id WHERE facility_id IS NOT NULL;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS idx_incidents_facility_id;
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE incidents DROP COLUMN facility_id;
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_incidents_receiving_facility_id ON incidents(receiving_facility_id);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_incidents_referring_facility_id ON incidents(referring_facility_id);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE MATERIALIZED VIEW mv_incident_daily_stats AS
SELECT
    date_trunc('day', i.reported_at)::date AS stat_date,
    i.district_id,
    i.referring_facility_id AS facility_id,
    COUNT(*) AS incidents_total,
    COUNT(*) FILTER (WHERE rpl.code = 'RED') AS red_triage_count,
    COUNT(*) FILTER (
        WHERE i.status IN ('ASSIGNED', 'ENROUTE', 'AT_SCENE', 'TRANSPORTING', 'COMPLETED')
    ) AS transfers_count,
    COUNT(*) FILTER (
        WHERE rit.code = 'MATERNAL_EMERGENCY'
    ) AS mnmci_count,
    COUNT(*) FILTER (
        WHERE rit.code = 'ACCIDENT'
           OR i.summary ILIKE '%rta%'
           OR i.description ILIKE '%rta%'
    ) AS rta_count,
    COUNT(*) FILTER (
        WHERE rit.code = 'HIGHLY_INFECTIOUS'
           OR i.summary ILIKE '%infectious%'
           OR i.description ILIKE '%infectious%'
    ) AS infectious_count
FROM incidents i
LEFT JOIN ref_priority_levels rpl ON rpl.id = i.priority_level_id
LEFT JOIN ref_incident_types rit ON rit.id = i.incident_type_id
GROUP BY 1, 2, 3;
-- +goose StatementEnd
-- +goose StatementBegin
CREATE UNIQUE INDEX uq_mv_incident_daily_stats
ON mv_incident_daily_stats(stat_date, district_id, facility_id);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_mv_incident_daily_stats_district_id
ON mv_incident_daily_stats(district_id);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_mv_incident_daily_stats_facility_id
ON mv_incident_daily_stats(facility_id);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE MATERIALIZED VIEW mv_dashboard_daily_summary AS
WITH ambulance_stats AS (
    SELECT
        COALESCE(f.district_id, m.district_id) AS district_id,
        m.station_facility_id AS facility_id,
        COUNT(*) FILTER (WHERE rac.code = 'BLS' AND m.is_active = TRUE) AS bls_ambulances_count,
        COUNT(*) FILTER (WHERE rac.code = 'ALS' AND m.is_active = TRUE) AS als_ambulances_count,
        COUNT(*) FILTER (WHERE rac.code = 'BOAT' AND m.is_active = TRUE) AS marine_ambulances_count,
        COUNT(*) FILTER (WHERE m.is_active = TRUE) AS total_ambulances_count,
        COUNT(*) FILTER (
            WHERE COALESCE(m.readiness_dispatch_readiness, m.ambulance_dispatch_readiness) = 'DISPATCHABLE'
              AND m.is_active = TRUE
        ) AS dispatchable_ambulances_count
    FROM mv_ambulance_latest_readiness m
    LEFT JOIN ref_ambulance_categories rac ON rac.id = m.category_id
    LEFT JOIN ref_facilities f ON f.id = m.station_facility_id
    GROUP BY 1, 2
)
SELECT
    ids.stat_date,
    ids.district_id,
    ids.facility_id,
    ids.incidents_total,
    ids.red_triage_count,
    ids.transfers_count,
    ids.mnmci_count,
    ids.rta_count,
    ids.infectious_count,
    COALESCE(ast.bls_ambulances_count, 0) AS bls_ambulances_count,
    COALESCE(ast.als_ambulances_count, 0) AS als_ambulances_count,
    COALESCE(ast.marine_ambulances_count, 0) AS marine_ambulances_count,
    COALESCE(ast.total_ambulances_count, 0) AS total_ambulances_count,
    COALESCE(ast.dispatchable_ambulances_count, 0) AS dispatchable_ambulances_count
FROM mv_incident_daily_stats ids
LEFT JOIN ambulance_stats ast
    ON ast.district_id IS NOT DISTINCT FROM ids.district_id
   AND ast.facility_id IS NOT DISTINCT FROM ids.facility_id;
-- +goose StatementEnd
-- +goose StatementBegin
CREATE UNIQUE INDEX uq_mv_dashboard_daily_summary
ON mv_dashboard_daily_summary(stat_date, district_id, facility_id);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_mv_dashboard_daily_summary_district_id
ON mv_dashboard_daily_summary(district_id);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_mv_dashboard_daily_summary_facility_id
ON mv_dashboard_daily_summary(facility_id);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE VIEW vw_incident_summary AS
SELECT
    i.id,
    i.incident_number,
    i.reported_at,
    i.status,
    i.verification_status,
    it.code AS incident_type_code,
    it.name AS incident_type_name,
    pl.code AS priority_code,
    pl.name AS priority_name,
    sl.code AS severity_code,
    sl.name AS severity_name,
    d.name AS district_name,
    i.pickup_location,
    rf.name AS referring_facility_name,
    cf.name AS receiving_facility_name,
    da.id AS dispatch_assignment_id,
    da.ambulance_id,
    da.status AS dispatch_status,
    da.assigned_at,
    da.completed_at,
    CASE
        WHEN da.assigned_at IS NOT NULL THEN EXTRACT(EPOCH FROM (da.assigned_at - i.reported_at)) / 60.0
        ELSE NULL
    END AS minutes_to_assignment,
    CASE
        WHEN da.completed_at IS NOT NULL THEN EXTRACT(EPOCH FROM (da.completed_at - i.reported_at)) / 60.0
        ELSE NULL
    END AS minutes_to_completion
FROM incidents i
LEFT JOIN ref_incident_types it ON it.id = i.incident_type_id
LEFT JOIN ref_priority_levels pl ON pl.id = i.priority_level_id
LEFT JOIN ref_severity_levels sl ON sl.id = i.severity_level_id
LEFT JOIN ref_districts d ON d.id = i.district_id
LEFT JOIN ref_facilities rf ON rf.id = i.referring_facility_id
LEFT JOIN ref_facilities cf ON cf.id = i.receiving_facility_id
LEFT JOIN dispatch_assignments da ON da.incident_id = i.id;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP VIEW IF EXISTS vw_incident_summary;
-- +goose StatementEnd
-- +goose StatementBegin
DROP MATERIALIZED VIEW IF EXISTS mv_dashboard_daily_summary;
-- +goose StatementEnd
-- +goose StatementBegin
DROP MATERIALIZED VIEW IF EXISTS mv_incident_daily_stats;
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE incidents ADD COLUMN facility_id UUID REFERENCES ref_facilities(id);
-- +goose StatementEnd
-- +goose StatementBegin
UPDATE incidents SET facility_id = referring_facility_id WHERE referring_facility_id IS NOT NULL;
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_incidents_facility_id ON incidents(facility_id);
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS idx_incidents_receiving_facility_id;
-- +goose StatementEnd
-- +goose StatementBegin
DROP INDEX IF EXISTS idx_incidents_referring_facility_id;
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE incidents DROP COLUMN pickup_location;
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE incidents DROP COLUMN receiving_facility_id;
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE incidents DROP COLUMN referring_facility_id;
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE incidents DROP COLUMN patient_details_diagnosis;
-- +goose StatementEnd

-- +goose StatementBegin
CREATE MATERIALIZED VIEW mv_incident_daily_stats AS
SELECT
    date_trunc('day', i.reported_at)::date AS stat_date,
    i.district_id,
    i.facility_id,
    COUNT(*) AS incidents_total,
    COUNT(*) FILTER (WHERE rpl.code = 'RED') AS red_triage_count,
    COUNT(*) FILTER (
        WHERE i.status IN ('ASSIGNED', 'ENROUTE', 'AT_SCENE', 'TRANSPORTING', 'COMPLETED')
    ) AS transfers_count,
    COUNT(*) FILTER (
        WHERE rit.code = 'MATERNAL_EMERGENCY'
    ) AS mnmci_count,
    COUNT(*) FILTER (
        WHERE rit.code = 'ACCIDENT'
           OR i.summary ILIKE '%rta%'
           OR i.description ILIKE '%rta%'
    ) AS rta_count,
    COUNT(*) FILTER (
        WHERE rit.code = 'HIGHLY_INFECTIOUS'
           OR i.summary ILIKE '%infectious%'
           OR i.description ILIKE '%infectious%'
    ) AS infectious_count
FROM incidents i
LEFT JOIN ref_priority_levels rpl ON rpl.id = i.priority_level_id
LEFT JOIN ref_incident_types rit ON rit.id = i.incident_type_id
GROUP BY 1, 2, 3;
-- +goose StatementEnd
-- +goose StatementBegin
CREATE UNIQUE INDEX uq_mv_incident_daily_stats
ON mv_incident_daily_stats(stat_date, district_id, facility_id);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_mv_incident_daily_stats_district_id
ON mv_incident_daily_stats(district_id);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_mv_incident_daily_stats_facility_id
ON mv_incident_daily_stats(facility_id);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE MATERIALIZED VIEW mv_dashboard_daily_summary AS
WITH ambulance_stats AS (
    SELECT
        COALESCE(f.district_id, m.district_id) AS district_id,
        m.station_facility_id AS facility_id,
        COUNT(*) FILTER (WHERE rac.code = 'BLS' AND m.is_active = TRUE) AS bls_ambulances_count,
        COUNT(*) FILTER (WHERE rac.code = 'ALS' AND m.is_active = TRUE) AS als_ambulances_count,
        COUNT(*) FILTER (WHERE rac.code = 'BOAT' AND m.is_active = TRUE) AS marine_ambulances_count,
        COUNT(*) FILTER (WHERE m.is_active = TRUE) AS total_ambulances_count,
        COUNT(*) FILTER (
            WHERE COALESCE(m.readiness_dispatch_readiness, m.ambulance_dispatch_readiness) = 'DISPATCHABLE'
              AND m.is_active = TRUE
        ) AS dispatchable_ambulances_count
    FROM mv_ambulance_latest_readiness m
    LEFT JOIN ref_ambulance_categories rac ON rac.id = m.category_id
    LEFT JOIN ref_facilities f ON f.id = m.station_facility_id
    GROUP BY 1, 2
)
SELECT
    ids.stat_date,
    ids.district_id,
    ids.facility_id,
    ids.incidents_total,
    ids.red_triage_count,
    ids.transfers_count,
    ids.mnmci_count,
    ids.rta_count,
    ids.infectious_count,
    COALESCE(ast.bls_ambulances_count, 0) AS bls_ambulances_count,
    COALESCE(ast.als_ambulances_count, 0) AS als_ambulances_count,
    COALESCE(ast.marine_ambulances_count, 0) AS marine_ambulances_count,
    COALESCE(ast.total_ambulances_count, 0) AS total_ambulances_count,
    COALESCE(ast.dispatchable_ambulances_count, 0) AS dispatchable_ambulances_count
FROM mv_incident_daily_stats ids
LEFT JOIN ambulance_stats ast
    ON ast.district_id IS NOT DISTINCT FROM ids.district_id
   AND ast.facility_id IS NOT DISTINCT FROM ids.facility_id;
-- +goose StatementEnd
-- +goose StatementBegin
CREATE UNIQUE INDEX uq_mv_dashboard_daily_summary
ON mv_dashboard_daily_summary(stat_date, district_id, facility_id);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_mv_dashboard_daily_summary_district_id
ON mv_dashboard_daily_summary(district_id);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_mv_dashboard_daily_summary_facility_id
ON mv_dashboard_daily_summary(facility_id);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE VIEW vw_incident_summary AS
SELECT
    i.id,
    i.incident_number,
    i.reported_at,
    i.status,
    i.verification_status,
    it.code AS incident_type_code,
    it.name AS incident_type_name,
    pl.code AS priority_code,
    pl.name AS priority_name,
    sl.code AS severity_code,
    sl.name AS severity_name,
    d.name AS district_name,
    f.name AS facility_name,
    da.id AS dispatch_assignment_id,
    da.ambulance_id,
    da.status AS dispatch_status,
    da.assigned_at,
    da.completed_at,
    CASE
        WHEN da.assigned_at IS NOT NULL THEN EXTRACT(EPOCH FROM (da.assigned_at - i.reported_at)) / 60.0
        ELSE NULL
    END AS minutes_to_assignment,
    CASE
        WHEN da.completed_at IS NOT NULL THEN EXTRACT(EPOCH FROM (da.completed_at - i.reported_at)) / 60.0
        ELSE NULL
    END AS minutes_to_completion
FROM incidents i
LEFT JOIN ref_incident_types it ON it.id = i.incident_type_id
LEFT JOIN ref_priority_levels pl ON pl.id = i.priority_level_id
LEFT JOIN ref_severity_levels sl ON sl.id = i.severity_level_id
LEFT JOIN ref_districts d ON d.id = i.district_id
LEFT JOIN ref_facilities f ON f.id = i.facility_id
LEFT JOIN dispatch_assignments da ON da.incident_id = i.id;
-- +goose StatementEnd
