-- Database Initialization Script for DevSecOps Interview Lab
-- This script creates the database schema and inserts test data
-- for the vulnerable Flask application

-- Create database and user (if not exists)
CREATE DATABASE IF NOT EXISTS vulnerable_app;
CREATE USER IF NOT EXISTS 'appuser'@'%' IDENTIFIED BY 'apppass';
GRANT ALL PRIVILEGES ON vulnerable_app.* TO 'appuser'@'%';
FLUSH PRIVILEGES;

-- Use the database
USE vulnerable_app;

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(100) NOT NULL,
    email VARCHAR(100),
    is_admin BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create posts table
CREATE TABLE IF NOT EXISTS posts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    content TEXT,
    author_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (author_id) REFERENCES users(id)
);

-- Create comments table
CREATE TABLE IF NOT EXISTS comments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    post_id INT,
    author VARCHAR(50),
    content TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES posts(id)
);

-- Insert test users
INSERT INTO users (username, password, email, is_admin) VALUES 
('admin', 'admin123', 'admin@example.com', TRUE),
('user1', 'password123', 'user1@example.com', FALSE),
('user2', 'password456', 'user2@example.com', FALSE),
('testuser', 'testpass', 'test@example.com', FALSE);

-- Insert test posts
INSERT INTO posts (title, content, author_id) VALUES 
('Welcome to the Vulnerable App', 'This is a intentionally vulnerable application for security testing. It contains various security vulnerabilities that you should identify and protect against.', 1),
('SQL Injection Test Post', 'This post is specifically designed for testing SQL injection vulnerabilities. Try searching for it with malicious queries.', 1),
('XSS Testing Content', 'This post contains content that can be used to test Cross-Site Scripting (XSS) vulnerabilities in the comment system.', 1),
('Security Best Practices', 'When developing applications, always validate input, use parameterized queries, and implement proper authentication.', 2),
('Database Security', 'Database security is crucial. Always use least privilege access, encrypt sensitive data, and monitor for suspicious activity.', 2);

-- Insert test comments
INSERT INTO comments (post_id, author, content) VALUES 
(1, 'user1', 'Great post! This is very informative.'),
(1, 'user2', 'Thanks for sharing this information.'),
(2, 'user1', 'This is a test comment for SQL injection testing.'),
(2, 'user2', 'Another comment to test the system.'),
(3, 'user1', 'XSS testing comment with <script>alert("test")</script>'),
(3, 'user2', 'Another XSS test: <img src=x onerror=alert("XSS")>'),
(4, 'user1', 'Security is very important in web applications.'),
(4, 'user2', 'I agree, proper security measures are essential.'),
(5, 'user1', 'Database security is often overlooked but critical.'),
(5, 'user2', 'Monitoring and logging are key components of database security.');

-- Create additional test data for more realistic testing
INSERT INTO users (username, password, email, is_admin) VALUES 
('john_doe', 'john123', 'john@example.com', FALSE),
('jane_smith', 'jane456', 'jane@example.com', FALSE),
('bob_wilson', 'bob789', 'bob@example.com', FALSE);

INSERT INTO posts (title, content, author_id) VALUES 
('API Security', 'API security is becoming increasingly important as more applications rely on APIs for communication.', 6),
('Authentication Methods', 'There are various authentication methods available, each with their own security implications.', 7),
('Session Management', 'Proper session management is crucial for maintaining security in web applications.', 8);

INSERT INTO comments (post_id, author, content) VALUES 
(6, 'john_doe', 'API security is indeed crucial in modern applications.'),
(6, 'jane_smith', 'Great point about API security considerations.'),
(7, 'bob_wilson', 'Authentication is the foundation of application security.'),
(7, 'john_doe', 'Multi-factor authentication adds an extra layer of security.'),
(8, 'jane_smith', 'Session management is often implemented incorrectly.'),
(8, 'bob_wilson', 'Proper session timeout and invalidation are important.');

-- Create a view for testing (can be used for SQL injection)
CREATE VIEW user_posts AS
SELECT u.username, p.title, p.content, p.created_at
FROM users u
JOIN posts p ON u.id = p.author_id;

-- Insert some sensitive data for testing information disclosure
INSERT INTO users (username, password, email, is_admin) VALUES 
('sensitive_user', 'secret_password', 'sensitive@example.com', FALSE),
('admin_backup', 'backup_admin_pass', 'backup@example.com', TRUE);

-- Insert posts with sensitive information
INSERT INTO posts (title, content, author_id) VALUES 
('Internal Document', 'This is an internal document that should not be accessible to regular users.', 1),
('Confidential Information', 'This post contains confidential information that should be protected.', 1),
('System Configuration', 'Database connection string: postgresql://admin:password@localhost:5432/db', 1);

-- Create a stored procedure for testing (if supported)
DELIMITER //
CREATE PROCEDURE GetUserPosts(IN user_id INT)
BEGIN
    SELECT p.title, p.content, p.created_at
    FROM posts p
    WHERE p.author_id = user_id;
END //
DELIMITER ;

-- Grant execute permission on stored procedure
GRANT EXECUTE ON PROCEDURE vulnerable_app.GetUserPosts TO 'appuser'@'%';

-- Create an index for performance testing
CREATE INDEX idx_posts_author ON posts(author_id);
CREATE INDEX idx_comments_post ON comments(post_id);
CREATE INDEX idx_users_username ON users(username);

-- Insert some additional test data for load testing
INSERT INTO posts (title, content, author_id) VALUES 
('Load Test Post 1', 'This is a load test post for performance testing.', 1),
('Load Test Post 2', 'Another load test post for performance testing.', 1),
('Load Test Post 3', 'Third load test post for performance testing.', 1);

-- Insert additional comments for load testing
INSERT INTO comments (post_id, author, content) VALUES 
(9, 'user1', 'Load test comment 1'),
(9, 'user2', 'Load test comment 2'),
(10, 'user1', 'Load test comment 3'),
(10, 'user2', 'Load test comment 4'),
(11, 'user1', 'Load test comment 5'),
(11, 'user2', 'Load test comment 6');

-- Show the created data
SELECT 'Database initialization completed successfully!' as status;
SELECT COUNT(*) as total_users FROM users;
SELECT COUNT(*) as total_posts FROM posts;
SELECT COUNT(*) as total_comments FROM comments;
