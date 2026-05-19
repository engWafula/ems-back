package infrastructure

import (
	"context"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"

	dashboardapp "dispatch/internal/modules/dashboard/application"
	dashboarddomain "dispatch/internal/modules/dashboard/domain"
)

type Repository struct {
	db *pgxpool.Pool
}

func NewRepository(db *pgxpool.Pool) *Repository { return &Repository{db: db} }

var _ dashboardapp.Repository = (*Repository)(nil)

type filterParts struct {
	mvWhere        string
	incidentWhere  string
	facilityWhere  string
	ambulanceWhere string
	args           []any
	mvArgs         []any
}

func buildFilters(filters dashboarddomain.DashboardFilters) filterParts {
	p := filterParts{
		mvWhere:        "1=1",
		incidentWhere:  "1=1",
		facilityWhere:  "1=1",
		ambulanceWhere: "1=1",
		args:           []any{},
		mvArgs:         []any{},
	}

	incidentClauses := []string{"1=1"}
	facilityClauses := []string{"1=1"}
	ambulanceClauses := []string{"1=1"}
	mvClauses := []string{"1=1"}

	argPos := 1
	mvArgPos := 1

	if filters.DateFrom != nil {
		incidentClauses = append(incidentClauses, fmt.Sprintf("i.reported_at >= $%d", argPos))
		p.args = append(p.args, *filters.DateFrom)
		argPos++

		mvClauses = append(mvClauses, fmt.Sprintf("stat_date >= $%d", mvArgPos))
		p.mvArgs = append(p.mvArgs, *filters.DateFrom)
		mvArgPos++
	}

	if filters.DateTo != nil {
		incidentClauses = append(incidentClauses, fmt.Sprintf("i.reported_at <= $%d", argPos))
		p.args = append(p.args, *filters.DateTo)
		argPos++

		mvClauses = append(mvClauses, fmt.Sprintf("stat_date <= $%d", mvArgPos))
		p.mvArgs = append(p.mvArgs, *filters.DateTo)
		mvArgPos++
	}

	if filters.DistrictID != nil {
		incidentClauses = append(incidentClauses, fmt.Sprintf("i.district_id = $%d", argPos))
		facilityClauses = append(facilityClauses, fmt.Sprintf("f.district_id = $%d", argPos))
		ambulanceClauses = append(ambulanceClauses, fmt.Sprintf("(m.district_id = $%d OR m.station_facility_id IN (SELECT id FROM ref_facilities WHERE district_id = $%d))", argPos, argPos))
		p.args = append(p.args, *filters.DistrictID)
		argPos++

		mvClauses = append(mvClauses, fmt.Sprintf("district_id = $%d", mvArgPos))
		p.mvArgs = append(p.mvArgs, *filters.DistrictID)
		mvArgPos++
	}

	if filters.FacilityID != nil {
		incidentClauses = append(incidentClauses, fmt.Sprintf("i.facility_id = $%d", argPos))
		facilityClauses = append(facilityClauses, fmt.Sprintf("f.id = $%d", argPos))
		ambulanceClauses = append(ambulanceClauses, fmt.Sprintf("m.station_facility_id = $%d", argPos))
		p.args = append(p.args, *filters.FacilityID)
		argPos++

		mvClauses = append(mvClauses, fmt.Sprintf("facility_id = $%d", mvArgPos))
		p.mvArgs = append(p.mvArgs, *filters.FacilityID)
		mvArgPos++
	}

	p.mvWhere = strings.Join(mvClauses, " AND ")
	p.incidentWhere = strings.Join(incidentClauses, " AND ")
	p.facilityWhere = strings.Join(facilityClauses, " AND ")
	p.ambulanceWhere = strings.Join(ambulanceClauses, " AND ")

	return p
}

func (r *Repository) GetDashboard(ctx context.Context, filters dashboarddomain.DashboardFilters) (dashboarddomain.DashboardResponse, error) {
	resp := dashboarddomain.DashboardResponse{}
	resp.Filters = map[string]interface{}{
		"date_from":   filters.DateFrom,
		"date_to":     filters.DateTo,
		"district_id": filters.DistrictID,
		"facility_id": filters.FacilityID,
	}

	parts := buildFilters(filters)

	if err := r.loadKPIs(ctx, &resp, parts); err != nil {
		return resp, err
	}
	if err := r.loadAmbulanceStatusTable(ctx, &resp, parts); err != nil {
		return resp, err
	}
	if err := r.loadTransfersTrend(ctx, &resp, parts); err != nil {
		return resp, err
	}
	if err := r.loadFacilityCaseTrend(ctx, &resp, parts); err != nil {
		return resp, err
	}
	if err := r.loadCommitteeDonuts(ctx, &resp); err != nil {
		return resp, err
	}

	_ = r.db.QueryRow(ctx, `SELECT MAX(created_at) FROM mv_dashboard_daily_summary`).Scan(&resp.LastUpdatedAt)

	return resp, nil
}

func (r *Repository) loadKPIs(ctx context.Context, resp *dashboarddomain.DashboardResponse, parts filterParts) error {
	facilityBase := fmt.Sprintf(`
		SELECT COUNT(DISTINCT f.id)
		FROM ref_facilities f
		WHERE %s
	`, parts.facilityWhere)
	_ = r.db.QueryRow(ctx, facilityBase, parts.args...).Scan(&resp.KPIs.ConstituenciesCount)

	q := fmt.Sprintf(`
		SELECT
			COALESCE(SUM(bls_ambulances_count), 0),
			COALESCE(SUM(als_ambulances_count), 0),
			COALESCE(SUM(total_ambulances_count), 0),
			COALESCE(SUM(marine_ambulances_count), 0),
			COALESCE(SUM(transfers_count), 0),
			COALESCE(SUM(red_triage_count), 0),
			COALESCE(SUM(infectious_count), 0),
			COALESCE(SUM(mnmci_count), 0),
			COALESCE(SUM(rta_count), 0)
		FROM mv_dashboard_daily_summary
		WHERE %s
	`, parts.mvWhere)

	var bls, als, total, marine, transfers, red, infectious, mnmci, rta int64
	if err := r.db.QueryRow(ctx, q, parts.mvArgs...).Scan(
		&bls, &als, &total, &marine, &transfers, &red, &infectious, &mnmci, &rta,
	); err != nil {
		return err
	}

	resp.KPIs.BLSAmbulancesCount = bls
	resp.KPIs.ALSAmbulancesCount = als
	resp.KPIs.TransfersCount = transfers
	resp.KPIs.RedTriagePatientsCount = red
	resp.KPIs.HighlyInfectiousPatientsCount = infectious
	resp.KPIs.MNMCI = mnmci
	resp.KPIs.RTA = rta

	if total > 0 {
		resp.KPIs.BLSAmbulancesProportion = (float64(bls) / float64(total)) * 100
		resp.KPIs.ALSAmbulancesProportion = (float64(als) / float64(total)) * 100
		resp.KPIs.MarineAmbulanceProportion = (float64(marine) / float64(total)) * 100
	}

	// Optional training metrics; kept safe if table exists.
	_ = r.db.QueryRow(ctx, `
		SELECT
			COUNT(DISTINCT user_id) FILTER (WHERE training_code = 'BEC') AS bec,
			COUNT(DISTINCT user_id) FILTER (WHERE training_code = 'BLS') AS bls,
			COUNT(DISTINCT user_id) FILTER (WHERE training_code = 'ALS') AS als,
			COUNT(DISTINCT user_id) FILTER (WHERE training_code = 'CCN') AS ccn,
			COUNT(DISTINCT user_id) FILTER (WHERE training_code = 'EMT') AS emt,
			COUNT(DISTINCT user_id) FILTER (WHERE training_code = 'AMBULANCE_DRIVER') AS drivers
		FROM user_training_records
	`).Scan(
		&resp.KPIs.HCWsTrainedBEC,
		&resp.KPIs.HCWsTrainedBLS,
		&resp.KPIs.HCWsTrainedALS,
		&resp.KPIs.HCWsTrainedCCN,
		&resp.KPIs.EMTsTrained,
		&resp.KPIs.TrainedAmbulanceDrivers,
	)

	return nil
}

func (r *Repository) loadAmbulanceStatusTable(ctx context.Context, resp *dashboarddomain.DashboardResponse, parts filterParts) error {
	q := fmt.Sprintf(`
		SELECT
			COALESCE(d.name, '') AS district,
			COALESCE(f.name, '') AS ambulance_station,
			COALESCE(m.plate_number, '') AS plate_number,
			COALESCE(rac.code, '') AS category,
			COALESCE(m.mechanical_status, 'UNKNOWN') AS mechanical_status,
			COALESCE(m.readiness_dispatch_readiness, m.ambulance_dispatch_readiness, 'UNKNOWN') AS dispatch_readiness,
			COALESCE(m.fuel_status, 'UNKNOWN') AS fuel_status,
			COALESCE(m.oxygen_status, 'UNKNOWN') AS oxygen_status,
			COALESCE(m.communication_status, 'UNKNOWN') AS communication_status
		FROM mv_ambulance_latest_readiness m
		LEFT JOIN ref_facilities f ON f.id = m.station_facility_id
		LEFT JOIN ref_districts d ON d.id = COALESCE(m.district_id, f.district_id)
		LEFT JOIN ref_ambulance_categories rac ON rac.id = m.category_id
		WHERE %s
		ORDER BY d.name, f.name, m.plate_number
		LIMIT 50
	`, parts.ambulanceWhere)

	rows, err := r.db.Query(ctx, q, parts.args...)
	if err != nil {
		return err
	}
	defer rows.Close()

	items := []dashboarddomain.AmbulanceStatusRow{}
	for rows.Next() {
		var row dashboarddomain.AmbulanceStatusRow
		if err := rows.Scan(
			&row.District,
			&row.AmbulanceStation,
			&row.PlateNumber,
			&row.Category,
			&row.MechanicalStatus,
			&row.DispatchReadiness,
			&row.FuelStatus,
			&row.OxygenStatus,
			&row.CommunicationStatus,
		); err != nil {
			return err
		}
		items = append(items, row)
	}
	resp.AmbulanceStatusTable = items
	return rows.Err()
}

func (r *Repository) loadTransfersTrend(ctx context.Context, resp *dashboarddomain.DashboardResponse, parts filterParts) error {
	q := fmt.Sprintf(`
		SELECT
			to_char(stat_date, 'YYYY-MM-DD') AS bucket,
			COALESCE(SUM(transfers_count), 0) AS value
		FROM mv_dashboard_daily_summary
		WHERE %s
		GROUP BY stat_date
		ORDER BY stat_date
		LIMIT 31
	`, parts.mvWhere)

	rows, err := r.db.Query(ctx, q, parts.mvArgs...)
	if err != nil {
		return err
	}
	defer rows.Close()

	items := []dashboarddomain.TrendPoint{}
	for rows.Next() {
		var p dashboarddomain.TrendPoint
		if err := rows.Scan(&p.Bucket, &p.Value); err != nil {
			return err
		}
		items = append(items, p)
	}
	resp.TransfersTrend = items
	return rows.Err()
}

func (r *Repository) loadFacilityCaseTrend(ctx context.Context, resp *dashboarddomain.DashboardResponse, parts filterParts) error {
	q := fmt.Sprintf(`
		SELECT
			COALESCE(f.name, 'Unknown') AS bucket,
			COUNT(*) AS total_cases
		FROM incidents i
		LEFT JOIN ref_facilities f ON f.id = i.facility_id
		WHERE %s
		GROUP BY f.name
		ORDER BY total_cases DESC
		LIMIT 12
	`, parts.incidentWhere)

	rows, err := r.db.Query(ctx, q, parts.args...)
	if err != nil {
		return err
	}
	defer rows.Close()

	items := []dashboarddomain.TrendPoint{}
	for rows.Next() {
		var p dashboarddomain.TrendPoint
		if err := rows.Scan(&p.Bucket, &p.Value); err != nil {
			return err
		}
		items = append(items, p)
	}
	resp.FacilityCaseTrend = items
	return rows.Err()
}

func (r *Repository) loadCommitteeDonuts(ctx context.Context, resp *dashboarddomain.DashboardResponse) error {
	// Safe best-effort. If these summary tables do not exist yet, values remain zero.
	_ = r.db.QueryRow(ctx, `
		SELECT
			COUNT(*) FILTER (WHERE is_functional = TRUE) AS yes_count,
			COUNT(*) FILTER (WHERE is_functional = FALSE) AS no_count
		FROM ambulance_committees
	`).Scan(&resp.AmbulanceCommittees.Yes, &resp.AmbulanceCommittees.No)

	_ = r.db.QueryRow(ctx, `
		SELECT
			COUNT(*) FILTER (WHERE is_financed_by_llu = TRUE) AS yes_count,
			COUNT(*) FILTER (WHERE is_financed_by_llu = FALSE) AS no_count
		FROM ambulance_financing
	`).Scan(&resp.AmbulanceLLUFinancing.Yes, &resp.AmbulanceLLUFinancing.No)

	return nil
}