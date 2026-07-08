create or replace PROCEDURE escalate_overdue AS
    CURSOR c_overdue IS
        SELECT r.request_id, r.submitted_at, w.sla_hours, r.status
        FROM requests  r
        JOIN workflows w ON w.workflow_id = r.workflow_id
        WHERE r.status IN ('PENDING', 'IN_REVIEW', 'APPROVED', 'IN_PROGRESS')
        AND (FROM_TZ(r.submitted_at, 'UTC') + NUMTODSINTERVAL(w.sla_hours, 'HOUR')) < SYSTIMESTAMP;

    v_count NUMBER := 0;
    v_old_status requests.status%TYPE;
BEGIN
    FOR rec IN c_overdue LOOP
        DBMS_OUTPUT.PUT_LINE(rec.request_id);
        v_old_status := rec.status;

        UPDATE requests
        SET status = 'ESCALATED'
        WHERE request_id = rec.request_id;

        log_audit(
            p_table_name => 'REQUESTS',
            p_record_id => rec.request_id,
            p_action => 'UPDATE',
            p_changed_by => NULL,
            p_old_value => v_old_status,
            p_new_value => 'status=ESCALATED'
        );

        v_count := v_count + 1;
    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Escalated ' || v_count || ' overdue requests.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END escalate_overdue;