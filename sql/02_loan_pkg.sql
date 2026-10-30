-- =============================================================
-- LMS_LOAN_PKG — business rules for issuing and returning books
-- Example APEX usage (page process on the Issue Book page):
--   lms_loan_pkg.issue_book(p_book_id => :P5_BOOK_ID, p_member_id => :P5_MEMBER_ID);
-- Error codes: -20301 no copies, -20302 member suspended, -20303 loan limit,
--              -20304 loan not open, -20305 unknown book, -20306 unknown member,
--              -20307 invalid loan period
-- =============================================================

CREATE OR REPLACE PACKAGE lms_loan_pkg AS

  c_default_loan_days CONSTANT PLS_INTEGER := 14;
  c_max_open_loans    CONSTANT PLS_INTEGER := 5;
  c_fine_per_day      CONSTANT NUMBER      := 0.50;

  FUNCTION open_loans (p_member_id IN lms_members.member_id%TYPE) RETURN NUMBER;

  FUNCTION fine_for_days (p_days IN NUMBER) RETURN NUMBER DETERMINISTIC;

  PROCEDURE issue_book (
    p_book_id    IN lms_books.book_id%TYPE,
    p_member_id  IN lms_members.member_id%TYPE,
    p_loan_days  IN NUMBER DEFAULT c_default_loan_days
  );

  PROCEDURE return_book (p_loan_id IN lms_loans.loan_id%TYPE);

END lms_loan_pkg;
/

CREATE OR REPLACE PACKAGE BODY lms_loan_pkg AS

  FUNCTION open_loans (p_member_id IN lms_members.member_id%TYPE) RETURN NUMBER IS
    l_count NUMBER;
  BEGIN
    SELECT COUNT(*) INTO l_count
      FROM lms_loans
     WHERE member_id = p_member_id
       AND return_date IS NULL;
    RETURN l_count;
  END open_loans;

  FUNCTION fine_for_days (p_days IN NUMBER) RETURN NUMBER DETERMINISTIC IS
  BEGIN
    RETURN GREATEST(NVL(p_days, 0), 0) * c_fine_per_day;
  END fine_for_days;

  PROCEDURE issue_book (
    p_book_id    IN lms_books.book_id%TYPE,
    p_member_id  IN lms_members.member_id%TYPE,
    p_loan_days  IN NUMBER DEFAULT c_default_loan_days
  ) IS
    l_status lms_members.status%TYPE;
  BEGIN
    IF p_loan_days NOT BETWEEN 1 AND 60 THEN
      RAISE_APPLICATION_ERROR(-20307, 'Loan period must be between 1 and 60 days.');
    END IF;

    BEGIN
      SELECT status INTO l_status FROM lms_members WHERE member_id = p_member_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20306, 'Member ' || p_member_id || ' does not exist.');
    END;

    IF l_status <> 'ACTIVE' THEN
      RAISE_APPLICATION_ERROR(-20302, 'This member is suspended and cannot borrow books.');
    END IF;

    IF open_loans(p_member_id) >= c_max_open_loans THEN
      RAISE_APPLICATION_ERROR(-20303,
        'Loan limit reached: a member can hold ' || c_max_open_loans || ' books at a time.');
    END IF;

    -- The trigger LMS_LOANS_BI checks stock and reduces COPIES_AVAILABLE.
    INSERT INTO lms_loans (book_id, member_id, loan_date, due_date, status)
    VALUES (p_book_id, p_member_id, TRUNC(SYSDATE), TRUNC(SYSDATE) + p_loan_days, 'ISSUED');
  END issue_book;

  PROCEDURE return_book (p_loan_id IN lms_loans.loan_id%TYPE) IS
    l_due    lms_loans.due_date%TYPE;
    l_return lms_loans.return_date%TYPE;
  BEGIN
    BEGIN
      SELECT due_date, return_date
        INTO l_due, l_return
        FROM lms_loans
       WHERE loan_id = p_loan_id
         FOR UPDATE;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20304, 'Loan ' || p_loan_id || ' does not exist.');
    END;

    IF l_return IS NOT NULL THEN
      RAISE_APPLICATION_ERROR(-20304, 'This loan has already been returned.');
    END IF;

    UPDATE lms_loans
       SET return_date = TRUNC(SYSDATE),
           status      = 'RETURNED',
           fine_amount = fine_for_days(TRUNC(SYSDATE) - l_due)
     WHERE loan_id = p_loan_id;
  END return_book;

END lms_loan_pkg;
/
