CREATE TABLE workflow_stages (
    stage_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    workflow_id NUMBER NOT NULL,
    dept_id NUMBER,
    stage_name VARCHAR2(100) NOT NULL,
    stage_seq NUMBER(3) NOT NULL,
    required_level NUMBER(1) NOT NULL,
    CONSTRAINT fk_wfstage_workflow FOREIGN KEY (workflow_id) REFERENCES workflows(workflow_id),
    CONSTRAINT fk_wfstags_dept FOREIGN KEY (dept_id) REFERENCES departments(dept_id),
    CONSTRAINT uq_wf_seq UNIQUE (workflow_id, stage_seq)
);