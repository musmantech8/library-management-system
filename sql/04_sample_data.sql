-- =============================================================
-- Sample data (fictional members, example.com emails). Safe to run twice:
-- reference data uses MERGE and the loans block only runs on an empty table.
-- =============================================================

MERGE INTO lms_categories t
USING (SELECT 'Programming' AS category_name FROM dual UNION ALL
       SELECT 'Databases'      FROM dual UNION ALL
       SELECT 'Fiction'        FROM dual UNION ALL
       SELECT 'Self-development' FROM dual UNION ALL
       SELECT 'Science and History' FROM dual) s
ON (t.category_name = s.category_name)
WHEN NOT MATCHED THEN INSERT (category_name) VALUES (s.category_name);

MERGE INTO lms_books t
USING (
  SELECT '9780132350884' AS isbn, 'Clean Code' AS title, 'Robert C. Martin' AS author, 'Programming' AS category, 'PRG-01' AS shelf, 3 AS copies FROM dual UNION ALL
  SELECT '9780135957059', 'The Pragmatic Programmer', 'David Thomas, Andrew Hunt', 'Programming', 'PRG-02', 2 FROM dual UNION ALL
  SELECT '9781593279288', 'Python Crash Course', 'Eric Matthes', 'Programming', 'PRG-03', 2 FROM dual UNION ALL
  SELECT '9780596517748', 'JavaScript: The Good Parts', 'Douglas Crockford', 'Programming', 'PRG-04', 1 FROM dual UNION ALL
  SELECT '9781449324452', 'Oracle PL/SQL Programming', 'Steven Feuerstein', 'Databases', 'DB-01', 2 FROM dual UNION ALL
  SELECT '9780262046305', 'Introduction to Algorithms', 'Thomas H. Cormen et al.', 'Programming', 'PRG-05', 2 FROM dual UNION ALL
  SELECT '9780321965516', 'Dont Make Me Think', 'Steve Krug', 'Programming', 'PRG-06', 1 FROM dual UNION ALL
  SELECT '9780735211292', 'Atomic Habits', 'James Clear', 'Self-development', 'SD-01', 3 FROM dual UNION ALL
  SELECT '9780062315007', 'The Alchemist', 'Paulo Coelho', 'Fiction', 'FIC-01', 2 FROM dual UNION ALL
  SELECT '9780451524935', '1984', 'George Orwell', 'Fiction', 'FIC-02', 2 FROM dual UNION ALL
  SELECT '9780061120084', 'To Kill a Mockingbird', 'Harper Lee', 'Fiction', 'FIC-03', 1 FROM dual UNION ALL
  SELECT '9780062316097', 'Sapiens', 'Yuval Noah Harari', 'Science and History', 'SCI-01', 2 FROM dual
) s
ON (t.isbn = s.isbn)
WHEN NOT MATCHED THEN INSERT (isbn, title, author, category_id, shelf_code, copies_total, copies_available)
  VALUES (s.isbn, s.title, s.author,
          (SELECT category_id FROM lms_categories WHERE category_name = s.category),
          s.shelf, s.copies, s.copies);

MERGE INTO lms_members t
USING (
  SELECT 'Ayesha Khan' AS full_name, 'ayesha.khan@example.com' AS email, '0300-0000001' AS phone, 'ACTIVE' AS status FROM dual UNION ALL
  SELECT 'Bilal Ahmed',    'bilal.ahmed@example.com',    '0300-0000002', 'ACTIVE'    FROM dual UNION ALL
  SELECT 'Sara Malik',     'sara.malik@example.com',     '0300-0000003', 'ACTIVE'    FROM dual UNION ALL
  SELECT 'Hamza Raza',     'hamza.raza@example.com',     '0300-0000004', 'ACTIVE'    FROM dual UNION ALL
  SELECT 'Zainab Ali',     'zainab.ali@example.com',     '0300-0000005', 'ACTIVE'    FROM dual UNION ALL
  SELECT 'Omar Farooq',    'omar.farooq@example.com',    '0300-0000006', 'SUSPENDED' FROM dual UNION ALL
  SELECT 'Hina Siddiqui',  'hina.siddiqui@example.com',  '0300-0000007', 'ACTIVE'    FROM dual UNION ALL
  SELECT 'Usman Tariq',    'usman.tariq@example.com',    '0300-0000008', 'ACTIVE'    FROM dual
) s
ON (t.email = s.email)
WHEN NOT MATCHED THEN INSERT (full_name, email, phone, status)
  VALUES (s.full_name, s.email, s.phone, s.status);

-- A few loans so the dashboard has something to show: some on time, some
-- overdue, and two returned (one of them late, so it carries a fine).
DECLARE
  l_count NUMBER;

  PROCEDURE loan (p_isbn IN VARCHAR2, p_email IN VARCHAR2, p_days_ago IN NUMBER, p_loan_days IN NUMBER, p_return_in_days IN NUMBER DEFAULT NULL) IS
    l_book_id   lms_books.book_id%TYPE;
    l_member_id lms_members.member_id%TYPE;
    l_loan_id   lms_loans.loan_id%TYPE;
    l_due       DATE := TRUNC(SYSDATE) - p_days_ago + p_loan_days;
  BEGIN
    SELECT book_id   INTO l_book_id   FROM lms_books   WHERE isbn  = p_isbn;
    SELECT member_id INTO l_member_id FROM lms_members WHERE email = p_email;

    INSERT INTO lms_loans (book_id, member_id, loan_date, due_date, status)
    VALUES (l_book_id, l_member_id, TRUNC(SYSDATE) - p_days_ago, l_due, 'ISSUED')
    RETURNING loan_id INTO l_loan_id;

    IF p_return_in_days IS NOT NULL THEN
      UPDATE lms_loans
         SET return_date = TRUNC(SYSDATE),
             status      = 'RETURNED',
             fine_amount = lms_loan_pkg.fine_for_days(TRUNC(SYSDATE) - l_due)
       WHERE loan_id = l_loan_id;
    END IF;
  END loan;
BEGIN
  SELECT COUNT(*) INTO l_count FROM lms_loans;

  IF l_count = 0 THEN
    loan('9780132350884', 'ayesha.khan@example.com',   3, 14);        -- on time
    loan('9781449324452', 'bilal.ahmed@example.com',   5, 14);        -- on time
    loan('9780735211292', 'sara.malik@example.com',   20, 14);        -- 6 days overdue
    loan('9780451524935', 'hamza.raza@example.com',   25, 14);        -- 11 days overdue
    loan('9780135957059', 'zainab.ali@example.com',    2, 14);        -- on time
    loan('9780062315007', 'hina.siddiqui@example.com', 30, 14, 0);    -- returned late, fine charged
    loan('9780262046305', 'usman.tariq@example.com',   10, 14, 0);    -- returned on time
  END IF;
END;
/

COMMIT;
