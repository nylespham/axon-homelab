-- Database Initialization Script for DevSecOps Interview Lab (PostgreSQL)
-- Creates the schema and test data for the vulnerable Flask application.
--
-- Run as the postgres superuser against the vulnerable_app database, with
-- ON_ERROR_STOP so a failure aborts instead of reporting success:
--   psql -v ON_ERROR_STOP=1 -U postgres -d vulnerable_app -f init-db.sql
--
-- The database and the appuser role are created by the Helm chart
-- (auth.database / auth.username), not by this script, so no credentials
-- live here.
--
-- NOTE: the test data is intentionally insecure (plain-text passwords, XSS
-- payloads, leaked connection string) - it is the target for the lab's
-- security testing. The schema and privileges are not.

\set ON_ERROR_STOP on

BEGIN;

-- Create users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(100) NOT NULL,
    email VARCHAR(100),
    is_admin BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create posts table
CREATE TABLE posts (
    id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    content TEXT,
    author_id INT REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create comments table
CREATE TABLE comments (
    id SERIAL PRIMARY KEY,
    post_id INT REFERENCES posts(id),
    author VARCHAR(50),
    content TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert test users
INSERT INTO users (username, password, email, is_admin) VALUES
('admin', 'admin123', 'admin@example.com', TRUE),
('user1', 'password123', 'user1@example.com', FALSE),
('user2', 'password456', 'user2@example.com', FALSE),
('testuser', 'testpass', 'test@example.com', FALSE),
('john_doe', 'john123', 'john@example.com', FALSE),
('jane_smith', 'jane456', 'jane@example.com', FALSE),
('bob_wilson', 'bob789', 'bob@example.com', FALSE),
-- Sensitive data for testing information disclosure
('sensitive_user', 'secret_password', 'sensitive@example.com', FALSE),
('admin_backup', 'backup_admin_pass', 'backup@example.com', TRUE);

-- Posts reference authors by username instead of hard-coded IDs, so the data
-- can't drift out of sync with the generated keys
INSERT INTO posts (title, content, author_id)
SELECT p.title, p.content, u.id
FROM (VALUES
    ('Welcome to the Vulnerable App', 'This is a intentionally vulnerable application for security testing. It contains various security vulnerabilities that you should identify and protect against.', 'admin'),
    ('SQL Injection Test Post', 'This post is specifically designed for testing SQL injection vulnerabilities. Try searching for it with malicious queries.', 'admin'),
    ('XSS Testing Content', 'This post contains content that can be used to test Cross-Site Scripting (XSS) vulnerabilities in the comment system.', 'admin'),
    ('Security Best Practices', 'When developing applications, always validate input, use parameterized queries, and implement proper authentication.', 'user1'),
    ('Database Security', 'Database security is crucial. Always use least privilege access, encrypt sensitive data, and monitor for suspicious activity.', 'user1'),
    ('API Security', 'API security is becoming increasingly important as more applications rely on APIs for communication.', 'john_doe'),
    ('Authentication Methods', 'There are various authentication methods available, each with their own security implications.', 'jane_smith'),
    ('Session Management', 'Proper session management is crucial for maintaining security in web applications.', 'bob_wilson'),
    -- Posts with sensitive information
    ('Internal Document', 'This is an internal document that should not be accessible to regular users.', 'admin'),
    ('Confidential Information', 'This post contains confidential information that should be protected.', 'admin'),
    ('System Configuration', 'Database connection string: postgresql://admin:password@localhost:5432/db', 'admin'),
    -- Load test posts
    ('Load Test Post 1', 'This is a load test post for performance testing.', 'admin'),
    ('Load Test Post 2', 'Another load test post for performance testing.', 'admin'),
    ('Load Test Post 3', 'Third load test post for performance testing.', 'admin')
) AS p(title, content, username)
JOIN users u ON u.username = p.username;

-- Comments reference posts by title for the same reason
INSERT INTO comments (post_id, author, content)
SELECT p.id, c.author, c.content
FROM (VALUES
    ('Welcome to the Vulnerable App', 'user1', 'Great post! This is very informative.'),
    ('Welcome to the Vulnerable App', 'user2', 'Thanks for sharing this information.'),
    ('SQL Injection Test Post', 'user1', 'This is a test comment for SQL injection testing.'),
    ('SQL Injection Test Post', 'user2', 'Another comment to test the system.'),
    ('XSS Testing Content', 'user1', 'XSS testing comment with <script>alert("test")</script>'),
    ('XSS Testing Content', 'user2', 'Another XSS test: <img src=x onerror=alert("XSS")>'),
    ('Security Best Practices', 'user1', 'Security is very important in web applications.'),
    ('Security Best Practices', 'user2', 'I agree, proper security measures are essential.'),
    ('Database Security', 'user1', 'Database security is often overlooked but critical.'),
    ('Database Security', 'user2', 'Monitoring and logging are key components of database security.'),
    ('API Security', 'john_doe', 'API security is indeed crucial in modern applications.'),
    ('API Security', 'jane_smith', 'Great point about API security considerations.'),
    ('Authentication Methods', 'bob_wilson', 'Authentication is the foundation of application security.'),
    ('Authentication Methods', 'john_doe', 'Multi-factor authentication adds an extra layer of security.'),
    ('Session Management', 'jane_smith', 'Session management is often implemented incorrectly.'),
    ('Session Management', 'bob_wilson', 'Proper session timeout and invalidation are important.'),
    ('Load Test Post 1', 'user1', 'Load test comment 1'),
    ('Load Test Post 1', 'user2', 'Load test comment 2'),
    ('Load Test Post 2', 'user1', 'Load test comment 3'),
    ('Load Test Post 2', 'user2', 'Load test comment 4'),
    ('Load Test Post 3', 'user1', 'Load test comment 5'),
    ('Load Test Post 3', 'user2', 'Load test comment 6')
) AS c(post_title, author, content)
JOIN posts p ON p.title = c.post_title;

-- View joining users and posts
CREATE VIEW user_posts AS
SELECT u.username, p.title, p.content, p.created_at
FROM users u
JOIN posts p ON u.id = p.author_id;

-- Function returning a user's posts (PostgreSQL equivalent of the MySQL
-- stored procedure)
CREATE FUNCTION get_user_posts(p_user_id INT)
RETURNS TABLE (title VARCHAR, content TEXT, created_at TIMESTAMP)
LANGUAGE sql STABLE
AS $$
    SELECT p.title, p.content, p.created_at
    FROM posts p
    WHERE p.author_id = p_user_id;
$$;

-- Indexes (users.username is already indexed by its UNIQUE constraint)
CREATE INDEX idx_posts_author ON posts(author_id);
CREATE INDEX idx_comments_post ON comments(post_id);

-- Least privilege for the application role: it only reads and adds
-- comments. No DDL, UPDATE or DELETE, so SQL injection through the app
-- can't drop tables or flip is_admin.
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO appuser;
GRANT SELECT ON users, posts, comments, user_posts TO appuser;
GRANT INSERT ON comments TO appuser;
GRANT USAGE ON SEQUENCE comments_id_seq TO appuser;
REVOKE EXECUTE ON FUNCTION get_user_posts(INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_user_posts(INT) TO appuser;

COMMIT;

-- Show the created data
SELECT 'Database initialization completed successfully!' AS status;
SELECT COUNT(*) AS total_users FROM users;
SELECT COUNT(*) AS total_posts FROM posts;
SELECT COUNT(*) AS total_comments FROM comments;
