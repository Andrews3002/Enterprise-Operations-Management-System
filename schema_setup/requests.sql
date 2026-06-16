CREATE TABLE requests (
    request_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    workflow_id     NUMBER        NOT NULL,
    submitted_by    NUMBER        NOT NULL,
    current_stage   NUMBER,
    status          VARCHAR2(20)  DEFAULT 'PENDING' NOT NULL,
    notes           VARCHAR2(1000),
    submitted_at    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    resolved_at     TIMESTAMP,
    CONSTRAINT fk_req_workflow  FOREIGN KEY (workflow_id)   REFERENCES workflows(workflow_id),
    CONSTRAINT fk_req_submitter FOREIGN KEY (submitted_by)  REFERENCES employees(emp_id),
    CONSTRAINT fk_req_stage     FOREIGN KEY (current_stage) REFERENCES workflow_stages(stage_id),
    CONSTRAINT check_req_status   CHECK (status IN ('PENDING','IN_REVIEW','APPROVED','REJECTED','ESCALATED','CLOSED'))
);

ALTER TABLE requests
DROP CONSTRAINT check_req_status;

ALTER TABLE requests
ADD CONSTRAINT check_req_status
CHECK (
    status IN (
        'PENDING',
        'IN_REVIEW',
        'APPROVED',
        'REJECTED',
        'IN_PROGRESS',
        'COMPLETED',
        'CANCELLED',
        'ESCALATED'
    )
);