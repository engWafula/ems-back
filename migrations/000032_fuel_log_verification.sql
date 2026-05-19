-- ============================================
-- File: 000032_fuel_log_verification.sql
-- ============================================
-- Adds QR-based public verification to fuel logs:
--   * public_token  -> the value encoded in the scannable QR link
--   * dispense confirmation fields filled in by the fuel station attendant

-- +goose Up
-- +goose StatementBegin
ALTER TABLE fuel_logs
    ADD COLUMN IF NOT EXISTS public_token       TEXT,
    ADD COLUMN IF NOT EXISTS dispensed_at        TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS dispense_confirmed  BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS attendant_name      TEXT,
    ADD COLUMN IF NOT EXISTS attendant_phone     TEXT,
    ADD COLUMN IF NOT EXISTS attendant_notes     TEXT,
    ADD COLUMN IF NOT EXISTS confirmed_at        TIMESTAMPTZ;
-- +goose StatementEnd
-- +goose StatementBegin
UPDATE fuel_logs
SET public_token = encode(gen_random_bytes(24), 'hex')
WHERE public_token IS NULL;
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE fuel_logs ALTER COLUMN public_token SET NOT NULL;
-- +goose StatementEnd
-- +goose StatementBegin
CREATE UNIQUE INDEX IF NOT EXISTS uq_fuel_logs_public_token ON fuel_logs(public_token);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP INDEX IF EXISTS uq_fuel_logs_public_token;
-- +goose StatementEnd
-- +goose StatementBegin
ALTER TABLE fuel_logs
    DROP COLUMN IF EXISTS public_token,
    DROP COLUMN IF EXISTS dispensed_at,
    DROP COLUMN IF EXISTS dispense_confirmed,
    DROP COLUMN IF EXISTS attendant_name,
    DROP COLUMN IF EXISTS attendant_phone,
    DROP COLUMN IF EXISTS attendant_notes,
    DROP COLUMN IF EXISTS confirmed_at;
-- +goose StatementEnd
