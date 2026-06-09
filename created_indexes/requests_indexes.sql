CREATE INDEX idx_requests_status      ON requests(status);
CREATE INDEX idx_requests_submitter   ON requests(submitted_by);
CREATE INDEX idx_requests_workflow    ON requests(workflow_id);
CREATE INDEX idx_requests_submitted   ON requests(submitted_at);