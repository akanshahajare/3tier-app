-- ════════════════════════════════════════════════════════
--  TIER 3 — PostgreSQL Data Layer (Version 2)
--
--  Run this as postgres superuser:
--  psql -U postgres -f setup.sql
-- ════════════════════════════════════════════════════════

-- Step 1: Create database
CREATE DATABASE school_db;

-- Step 2: Connect to it
\c school_db;

-- Step 3: Create students table
CREATE TABLE IF NOT EXISTS students (
  id         SERIAL PRIMARY KEY,
  name       VARCHAR(100) NOT NULL,
  age        INTEGER      NOT NULL,
  course     VARCHAR(100) NOT NULL,
  created_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- Step 4: Insert sample data
INSERT INTO students (name, age, course) VALUES
  ('Ravi Kumar',    22, 'DevOps'),
  ('Priya Sharma',  21, 'Python'),
  ('Arjun Mehta',   23, 'Linux Admin'),
  ('Sneha Patil',   20, 'AWS Cloud'),
  ('Mohammed Ali',  24, 'Docker & Kubernetes');

-- Step 5: Create app user with least privilege
CREATE USER appuser WITH PASSWORD 'apppassword';
GRANT CONNECT ON DATABASE school_db TO appuser;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE students TO appuser;
GRANT USAGE, SELECT ON SEQUENCE students_id_seq TO appuser;

SELECT 'PostgreSQL setup complete!' AS status;
SELECT * FROM students;
