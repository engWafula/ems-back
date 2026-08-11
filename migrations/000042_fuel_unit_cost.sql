-- ============================================
-- File: 000042_fuel_unit_cost.sql
-- ============================================
-- Adds the per-liter unit cost captured at fueling. The user enters unit_cost
-- and liters; the total `cost` column is derived (liters * unit_cost) by the
-- API. unit_cost is nullable so existing rows keep NULL.

-- +goose Up
-- +goose StatementBegin
ALTER TABLE fuel_logs ADD COLUMN unit_cost NUMERIC(12,2) CHECK (unit_cost IS NULL OR unit_cost >= 0);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE fuel_logs DROP COLUMN unit_cost;
-- +goose StatementEnd
