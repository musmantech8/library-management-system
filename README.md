# Library Management System

A library application built with **Oracle APEX** and **PL/SQL**. Members borrow and return books, administrators manage the catalogue, members and loans, and fines are calculated automatically.

## Features

- **Dashboard:** titles, copies available, active members, open and overdue loans, with charts.
- **Books, members and loans:** interactive reports with forms, for administrators.
- **Own loans:** normal users see only their own loans.
- **Accounts:** self-service sign-up. The first account becomes the administrator.
- **Business rules in the database:** a copy is taken when a book is issued and returned when it is returned, a member can hold at most 5 books, suspended members cannot borrow, and fines are 0.50 per day late.

## Database

Run the scripts in `sql/` in this order:

| Script | What it creates |
| --- | --- |
| `01_schema.sql` | Tables, constraints, indexes and the loan triggers |
| `02_loan_pkg.sql` | `LMS_LOAN_PKG`: issue and return rules, fine calculation |
| `03_views.sql` | Report views and the return trigger |
| `04_sample_data.sql` | Categories, books, members and sample loans |
| `05_auth.sql` | Accounts, `LMS_AUTH_PKG` (hashed passwords, admin check), sign-up table and admin-only triggers |

Passwords are never stored in plain text. Each one is stored as a salted hash.

## Application

The APEX application uses a custom authentication scheme (`lms_auth_pkg.authenticate`) and an *Administration Rights* authorization scheme (`lms_auth_pkg.is_admin`). Administrator-only pages and menu items are protected by that scheme, and the database enforces the same rules.

### First run

1. Run the SQL scripts above in SQL Workshop.
2. Import the application into your workspace.
3. Open the sign-in page and choose **Create an account**. The first account becomes the administrator.

## Tech

Oracle APEX · Oracle Database · PL/SQL · SQL

---

Built by [Muhammad Usman](https://github.com/musmantech8), Oracle APEX Developer.
