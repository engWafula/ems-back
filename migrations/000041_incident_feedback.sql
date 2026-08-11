-- ============================================
-- File: 000041_incident_feedback.sql
-- ============================================
-- Adds receiving-facility feedback on a transferred/received patient. A facility
-- that receives a patient can record the clinical outcome and notes against the
-- originating incident. Multiple feedback entries per incident are allowed so the
-- history is preserved (e.g. admitted -> referred). The new incidents.feedback
-- permission guards submission and is granted to administrator, dispatch and
-- facility focal-person roles (the receiving facility's contact).

-- +goose Up
-- +goose StatementBegin
CREATE TABLE incident_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
    outcome_status TEXT NOT NULL CHECK (outcome_status IN (
        'ADMITTED', 'DISCHARGED', 'STABILIZED', 'REFERRED', 'DECEASED', 'OTHER'
    )),
    summary TEXT NOT NULL,
    reported_by TEXT,
    other_details TEXT,
    created_by_user_id UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- +goose StatementEnd
-- +goose StatementBegin
CREATE INDEX idx_incident_feedback_incident_id ON incident_feedback(incident_id);
-- +goose StatementEnd

-- +goose StatementBegin
INSERT INTO permissions (code, name, module, description) VALUES
('incidents.feedback', 'Submit incident feedback', 'incidents', 'Can submit receiving-facility feedback/outcome on an incident')
ON CONFLICT (code) DO NOTHING;
-- +goose StatementEnd
-- +goose StatementBegin
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code = 'incidents.feedback'
WHERE r.code IN (
    'SUPER_ADMIN', 'NATIONAL_ADMIN', 'DISTRICT_ADMIN',
    'DISPATCH_SUPERVISOR', 'DISPATCHER', 'FACILITY_FOCAL_PERSON'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DELETE FROM role_permissions rp
USING permissions p
WHERE rp.permission_id = p.id
  AND p.code = 'incidents.feedback';
-- +goose StatementEnd
-- +goose StatementBegin
DELETE FROM permissions WHERE code = 'incidents.feedback';
-- +goose StatementEnd
-- +goose StatementBegin
DROP TABLE IF EXISTS incident_feedback;
-- +goose StatementEnd
