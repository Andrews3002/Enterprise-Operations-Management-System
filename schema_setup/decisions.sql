CREATE TABLE decisions (
    decision_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    request_id    NUMBER        NOT NULL,
    stage_id      NUMBER        NOT NULL,
    decider_id   NUMBER        NOT NULL,
    decision      VARCHAR2(10)  NOT NULL,
    decision_at   TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    comments      VARCHAR2(500),
    CONSTRAINT fk_decision_request  FOREIGN KEY (request_id)  REFERENCES requests(request_id),
    CONSTRAINT fk_decision_stage    FOREIGN KEY (stage_id)    REFERENCES workflow_stages(stage_id),
    CONSTRAINT fk_decision_decider FOREIGN KEY (decider_id) REFERENCES employees(emp_id),
    CONSTRAINT check_decision CHECK (decision IN ('APPROVED','REJECTED'))
);