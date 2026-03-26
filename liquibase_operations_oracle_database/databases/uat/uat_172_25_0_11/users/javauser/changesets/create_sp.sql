-- liquibase formatted sql

-- changeset javauser:create_sp_1002 labels="create-sp" endDelimiter:/
-- comment: This changeset running to create a stored procedure
CREATE OR REPLACE PROCEDURE sample_procedure_javauser AS
BEGIN
   DBMS_OUTPUT.PUT_LINE('Executed sample procedure for javauser');
END;
/

-- rollback DROP PROCEDURE sample_procedure_javauser;
