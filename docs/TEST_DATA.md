# Test Data Overview

This document describes the test data provided in `init-db.sql` for the DevSecOps interview lab.

## Database Schema

### Tables Created

1. **users** - User accounts and authentication
   - `id` - Primary key
   - `username` - Unique username
   - `password` - Password (stored in plain text for testing)
   - `email` - User email
   - `is_admin` - Admin flag
   - `created_at` - Timestamp

2. **posts** - Blog posts/articles
   - `id` - Primary key
   - `title` - Post title
   - `content` - Post content
   - `author_id` - Foreign key to users
   - `created_at` - Timestamp

3. **comments** - Comments on posts
   - `id` - Primary key
   - `post_id` - Foreign key to posts
   - `author` - Comment author name
   - `content` - Comment content
   - `created_at` - Timestamp

### Additional Objects

- **user_posts** - View joining users and posts
- **GetUserPosts** - Stored procedure for testing
- **Indexes** - Performance indexes on key columns

## Test Data Included

### Users (10 total)
- **admin** - Admin user with elevated privileges
- **user1, user2** - Regular users for testing
- **testuser** - Additional test user
- **john_doe, jane_smith, bob_wilson** - Realistic user names
- **sensitive_user, admin_backup** - Sensitive accounts for testing

### Posts (11 total)
- Welcome and introduction posts
- Security-focused content
- Test posts for vulnerability testing
- Load testing posts
- Posts with sensitive information

### Comments (20+ total)
- Normal comments for legitimate testing
- XSS test comments with malicious scripts
- Comments for load testing
- Comments on various posts

## Security Testing Data

### SQL Injection Targets
- User enumeration via `/user/{id}`
- Search functionality with malicious queries
- Union-based injection testing
- Database schema discovery

### XSS Testing Data
- Stored XSS in comments
- Script tag injection
- Image-based XSS
- Event handler XSS

### Authentication Testing
- Admin accounts for privilege escalation
- Weak passwords for brute force testing
- Sensitive accounts for information disclosure

### Information Disclosure
- Debug endpoint with system information
- Sensitive user data
- Database connection strings
- Internal documents

## Usage in Interview

### For Candidates
1. **Database Setup** - Use `init-db.sql` to populate test data
2. **Vulnerability Testing** - Use provided data to test security issues
3. **WAF Testing** - Test WAF rules against known malicious content
4. **Performance Testing** - Use load test data for performance evaluation

### For Interviewers
1. **Evaluation** - Assess how candidates use the test data
2. **Testing Approach** - Observe their testing methodology
3. **Security Awareness** - Evaluate their understanding of vulnerabilities
4. **Documentation** - Review their analysis of findings

## Customization

Candidates can:
- Add additional test data
- Modify existing data
- Create custom test scenarios
- Add new tables or relationships

## Security Considerations

⚠️ **Warning**: This test data contains intentionally vulnerable content and should NEVER be used in production environments.

- Passwords are stored in plain text
- Sensitive information is included
- Malicious content is present
- Security vulnerabilities are intentional

## Database Statistics

After initialization:
- **Users**: 10 total
- **Posts**: 11 total  
- **Comments**: 20+ total
- **Views**: 1 (user_posts)
- **Procedures**: 1 (GetUserPosts)
- **Indexes**: 3 performance indexes

This provides a realistic dataset for comprehensive security testing and evaluation.
