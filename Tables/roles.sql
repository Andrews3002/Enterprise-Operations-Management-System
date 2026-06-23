CREATE TABLE roles (
    role_id     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role_name   VARCHAR2(50)  NOT NULL UNIQUE,
    role_level  NUMBER(1)     NOT NULL,
    CONSTRAINT check_role_level CHECK (role_level BETWEEN 1 AND 5)
);