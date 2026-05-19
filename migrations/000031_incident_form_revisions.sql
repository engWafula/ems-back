-- ============================================
-- File: 000031_incident_form_revisions.sql
-- ============================================
-- Aligns the incident form with EMS review feedback:
--   * widens the source_channel (mode of communication) check to match
--     the dispatcher console options
--   * renames priority levels to High / Medium / Low Priority

-- +goose Up
-- +goose StatementBegin
ALTER TABLE incidents DROP CONSTRAINT IF EXISTS incidents_source_channel_check;
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE incidents ADD CONSTRAINT incidents_source_channel_check
    CHECK (source_channel IN (
        'SMS', 'USSD', 'CALL', 'MOBILE_APP', 'WEB_PORTAL', 'FACILITY_REFERRAL',
        'RADIO', 'APP', 'WALK_IN', 'REFERRAL'
    ));
-- +goose StatementEnd
-- +goose StatementBegin
UPDATE ref_priority_levels SET name = 'High Priority' WHERE code = 'RED';
-- +goose StatementEnd
-- +goose StatementBegin
UPDATE ref_priority_levels SET name = 'Medium Priority' WHERE code = 'ORANGE';
-- +goose StatementEnd
-- +goose StatementBegin
UPDATE ref_priority_levels SET name = 'Low Priority' WHERE code = 'GREEN';
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
UPDATE ref_priority_levels SET name = 'Red Priority' WHERE code = 'RED';
-- +goose StatementEnd
-- +goose StatementBegin
UPDATE ref_priority_levels SET name = 'Orange Priority' WHERE code = 'ORANGE';
-- +goose StatementEnd
-- +goose StatementBegin
UPDATE ref_priority_levels SET name = 'Green Priority' WHERE code = 'GREEN';
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE incidents DROP CONSTRAINT IF EXISTS incidents_source_channel_check;
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE incidents ADD CONSTRAINT incidents_source_channel_check
    CHECK (source_channel IN (
        'SMS', 'USSD', 'CALL', 'MOBILE_APP', 'WEB_PORTAL', 'FACILITY_REFERRAL'
    ));
-- +goose StatementEnd
