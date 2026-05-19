-- ============================================
-- File: 000034_driver_medic_incidents_read.sql
-- ============================================
-- Grants the incidents.read permission to the DRIVER and MEDIC roles so that
-- responders can list the incidents assigned to them. The incidents list
-- endpoint scopes the results to a responder's own dispatch assignments.

-- +goose Up
-- +goose StatementBegin
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code = 'incidents.read'
WHERE r.code IN ('DRIVER', 'MEDIC')
ON CONFLICT (role_id, permission_id) DO NOTHING;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DELETE FROM role_permissions
WHERE role_id IN (SELECT id FROM roles WHERE code IN ('DRIVER', 'MEDIC'))
  AND permission_id IN (SELECT id FROM permissions WHERE code = 'incidents.read');
-- +goose StatementEnd
