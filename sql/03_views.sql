-- =============================================================
-- Return trigger and report views used by the APEX pages
-- =============================================================

-- Returning a loan (from the app or anywhere else) marks it RETURNED, works out
-- the fine, and puts the copy back on the shelf. A returned loan cannot be re-opened.
CREATE OR REPLACE TRIGGER lms_loans_bu
  BEFORE UPDATE OF return_date ON lms_loans
  FOR EACH ROW
BEGIN
  IF :OLD.return_date IS NULL AND :NEW.return_date IS NOT NULL THEN
    :NEW.return_date := TRUNC(:NEW.return_date);
    :NEW.status      := 'RETURNED';
    :NEW.fine_amount := lms_loan_pkg.fine_for_days(:NEW.return_date - :NEW.due_date);

    UPDATE lms_books
       SET copies_available = copies_available + 1
     WHERE book_id = :NEW.book_id;
  ELSIF :OLD.return_date IS NOT NULL AND :NEW.return_date IS NULL THEN
    RAISE_APPLICATION_ERROR(-20304, 'A returned loan cannot be re-opened.');
  END IF;
END;
/

-- Every loan with book and member names, days overdue and the fine due so far.
CREATE OR REPLACE VIEW lms_loans_v AS
SELECT l.loan_id,
       l.book_id,
       b.title,
       b.author,
       l.member_id,
       m.full_name AS member_name,
       l.loan_date,
       l.due_date,
       l.return_date,
       l.status,
       CASE WHEN l.return_date IS NULL AND TRUNC(SYSDATE) > l.due_date
            THEN TRUNC(SYSDATE) - l.due_date ELSE 0 END AS days_overdue,
       CASE WHEN l.return_date IS NULL
            THEN lms_loan_pkg.fine_for_days(TRUNC(SYSDATE) - l.due_date)
            ELSE l.fine_amount END AS fine_amount
  FROM lms_loans   l
  JOIN lms_books   b ON b.book_id   = l.book_id
  JOIN lms_members m ON m.member_id = l.member_id;
-- Note: 05_auth.sql replaces this view with the version that filters loans by user.

-- Books with their category and how many copies are out.
CREATE OR REPLACE VIEW lms_books_v AS
SELECT b.book_id,
       b.isbn,
       b.title,
       b.author,
       c.category_name,
       b.shelf_code,
       b.copies_total,
       b.copies_available,
       b.copies_total - b.copies_available AS copies_out,
       b.is_active
  FROM lms_books b
  JOIN lms_categories c ON c.category_id = b.category_id;

-- One row of numbers for the dashboard cards.
CREATE OR REPLACE VIEW lms_dashboard_v AS
SELECT (SELECT COUNT(*) FROM lms_books WHERE is_active = 'Y')                      AS titles,
       (SELECT NVL(SUM(copies_available), 0) FROM lms_books WHERE is_active = 'Y') AS copies_available,
       (SELECT COUNT(*) FROM lms_members WHERE status = 'ACTIVE')                  AS active_members,
       (SELECT COUNT(*) FROM lms_loans WHERE return_date IS NULL)                  AS open_loans,
       (SELECT COUNT(*) FROM lms_loans
         WHERE return_date IS NULL AND due_date < TRUNC(SYSDATE))                  AS overdue_loans
  FROM dual;
