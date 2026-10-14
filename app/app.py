#!/usr/bin/env python3
"""
Vulnerable Flask Application for Security Testing
This application contains intentional security vulnerabilities for educational purposes.
DO NOT use this in production!
"""

import os
import psycopg2
from flask import Flask, request, render_template_string, redirect, url_for, session, flash
import hashlib
import json
from urllib.parse import unquote

app = Flask(__name__)
app.secret_key = 'insecure-secret-key-change-in-production'

# Database configuration
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'postgres.database.svc.cluster.local'),
    'port': os.getenv('DB_PORT', '5432'),
    'database': os.getenv('DB_NAME', 'vulnerable_app'),
    'user': os.getenv('DB_USER', 'appuser'),
    'password': os.getenv('DB_PASSWORD', 'apppass')
}

def get_db_connection():
    """Get database connection - vulnerable to connection string injection"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        return conn
    except Exception as e:
        print(f"Database connection error: {e}")
        return None

# HTML Templates
INDEX_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>Vulnerable Flask App</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 800px; margin: 0 auto; }
        .vulnerability { background: #ffe6e6; padding: 10px; margin: 10px 0; border-left: 4px solid #ff0000; }
        .form-group { margin: 10px 0; }
        input, textarea { width: 100%; padding: 8px; margin: 5px 0; }
        button { background: #007bff; color: white; padding: 10px 20px; border: none; cursor: pointer; }
        .posts { margin: 20px 0; }
        .post { border: 1px solid #ddd; padding: 15px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Vulnerable Flask Application</h1>
        <div class="vulnerability">
            <strong>Warning:</strong> This application contains intentional security vulnerabilities for educational purposes.
        </div>
        
        <h2>Navigation</h2>
        <a href="/">Home</a> | 
        <a href="/search">Search</a> | 
        <a href="/posts">Posts</a> | 
        <a href="/admin">Admin</a> | 
        <a href="/login">Login</a>
        
        <h2>Search Posts (SQL Injection Test)</h2>
        <form method="GET" action="/search">
            <div class="form-group">
                <input type="text" name="q" placeholder="Search posts..." value="{{ query or '' }}">
                <button type="submit">Search</button>
            </div>
        </form>
        
        {% if results %}
        <h3>Search Results:</h3>
        {% for post in results %}
        <div class="post">
            <h4>{{ post.title }}</h4>
            <p>{{ post.content }}</p>
            <small>Author ID: {{ post.author_id }}</small>
        </div>
        {% endfor %}
        {% endif %}
        
        <h2>Add Comment (XSS Test)</h2>
        <form method="POST" action="/comment">
            <div class="form-group">
                <input type="text" name="author" placeholder="Your name" required>
            </div>
            <div class="form-group">
                <textarea name="content" placeholder="Your comment..." required></textarea>
            </div>
            <button type="submit">Add Comment</button>
        </form>
        
        {% if comments %}
        <h3>Recent Comments:</h3>
        {% for comment in comments %}
        <div class="post">
            <strong>{{ comment.author }}:</strong> {{ comment.content|safe }}
        </div>
        {% endfor %}
        {% endif %}
        
        <h2>User Info (Information Disclosure)</h2>
        <p><a href="/user/1">View User 1</a></p>
        <p><a href="/user/2">View User 2</a></p>
        <p><a href="/user/3">View User 3</a></p>
    </div>
</body>
</html>
"""

LOGIN_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>Login - Vulnerable Flask App</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 400px; margin: 0 auto; }
        input { width: 100%; padding: 8px; margin: 5px 0; }
        button { background: #007bff; color: white; padding: 10px 20px; border: none; cursor: pointer; width: 100%; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Login</h1>
        <form method="POST">
            <div>
                <input type="text" name="username" placeholder="Username" required>
            </div>
            <div>
                <input type="password" name="password" placeholder="Password" required>
            </div>
            <button type="submit">Login</button>
        </form>
        <p><a href="/">Back to Home</a></p>
    </div>
</body>
</html>
"""

@app.route('/')
def index():
    """Home page with search and comment functionality"""
    conn = get_db_connection()
    if not conn:
        return "Database connection failed", 500
    
    try:
        cursor = conn.cursor()
        # Get recent comments
        cursor.execute("SELECT author, content FROM comments ORDER BY created_at DESC LIMIT 5")
        comments = cursor.fetchall()
        cursor.close()
        conn.close()
        
        return render_template_string(INDEX_TEMPLATE, comments=comments)
    except Exception as e:
        return f"Error: {e}", 500

@app.route('/search')
def search():
    """Search functionality - vulnerable to SQL injection"""
    query = request.args.get('q', '')
    conn = get_db_connection()
    if not conn:
        return "Database connection failed", 500
    
    try:
        cursor = conn.cursor()
        # VULNERABLE: Direct string interpolation - SQL injection possible
        sql = f"SELECT id, title, content, author_id FROM posts WHERE title ILIKE '%{query}%' OR content ILIKE '%{query}%'"
        cursor.execute(sql)
        results = cursor.fetchall()
        cursor.close()
        conn.close()
        
        # Convert to list of dicts for template
        posts = []
        for row in results:
            posts.append({
                'id': row[0],
                'title': row[1],
                'content': row[2],
                'author_id': row[3]
            })
        
        return render_template_string(INDEX_TEMPLATE, query=query, results=posts)
    except Exception as e:
        return f"Error: {e}", 500

@app.route('/comment', methods=['POST'])
def add_comment():
    """Add comment - vulnerable to XSS"""
    author = request.form.get('author', '')
    content = request.form.get('content', '')
    
    if not author or not content:
        flash('Both author and content are required')
        return redirect(url_for('index'))
    
    conn = get_db_connection()
    if not conn:
        return "Database connection failed", 500
    
    try:
        cursor = conn.cursor()
        # VULNERABLE: No input sanitization - XSS possible
        cursor.execute("INSERT INTO comments (author, content) VALUES (%s, %s)", (author, content))
        conn.commit()
        cursor.close()
        conn.close()
        
        flash('Comment added successfully!')
        return redirect(url_for('index'))
    except Exception as e:
        return f"Error: {e}", 500

@app.route('/user/<int:user_id>')
def get_user(user_id):
    """Get user information - vulnerable to information disclosure"""
    conn = get_db_connection()
    if not conn:
        return "Database connection failed", 500
    
    try:
        cursor = conn.cursor()
        # VULNERABLE: No authorization check - information disclosure
        cursor.execute("SELECT id, username, email, is_admin, created_at FROM users WHERE id = %s", (user_id,))
        user = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if user:
            return f"""
            <h1>User Information</h1>
            <p><strong>ID:</strong> {user[0]}</p>
            <p><strong>Username:</strong> {user[1]}</p>
            <p><strong>Email:</strong> {user[2]}</p>
            <p><strong>Is Admin:</strong> {user[3]}</p>
            <p><strong>Created:</strong> {user[4]}</p>
            <p><a href="/">Back to Home</a></p>
            """
        else:
            return "User not found", 404
    except Exception as e:
        return f"Error: {e}", 500

@app.route('/admin')
def admin():
    """Admin panel - vulnerable to privilege escalation"""
    # VULNERABLE: No proper authentication/authorization
    if request.headers.get('X-Forwarded-For') == '127.0.0.1':
        return """
        <h1>Admin Panel</h1>
        <p>Welcome, admin!</p>
        <p>You have access to sensitive operations.</p>
        <p><a href="/">Back to Home</a></p>
        """
    else:
        return "Access denied", 403

@app.route('/login', methods=['GET', 'POST'])
def login():
    """Login functionality - vulnerable to authentication bypass"""
    if request.method == 'GET':
        return render_template_string(LOGIN_TEMPLATE)
    
    username = request.form.get('username', '')
    password = request.form.get('password', '')
    
    conn = get_db_connection()
    if not conn:
        return "Database connection failed", 500
    
    try:
        cursor = conn.cursor()
        # VULNERABLE: Weak password hashing and no rate limiting
        cursor.execute("SELECT id, username, password, is_admin FROM users WHERE username = %s", (username,))
        user = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if user and user[2] == password:  # VULNERABLE: Plain text password comparison
            session['user_id'] = user[0]
            session['username'] = user[1]
            session['is_admin'] = user[3]
            flash('Login successful!')
            return redirect(url_for('index'))
        else:
            flash('Invalid credentials')
            return render_template_string(LOGIN_TEMPLATE)
    except Exception as e:
        return f"Error: {e}", 500

@app.route('/posts')
def posts():
    """List all posts"""
    conn = get_db_connection()
    if not conn:
        return "Database connection failed", 500
    
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT id, title, content, author_id, created_at FROM posts ORDER BY created_at DESC")
        posts = cursor.fetchall()
        cursor.close()
        conn.close()
        
        html = "<h1>All Posts</h1>"
        for post in posts:
            html += f"""
            <div class="post">
                <h3>{post[1]}</h3>
                <p>{post[2]}</p>
                <small>Author ID: {post[3]} | Created: {post[4]}</small>
            </div>
            """
        html += '<p><a href="/">Back to Home</a></p>'
        return html
    except Exception as e:
        return f"Error: {e}", 500

@app.route('/debug')
def debug():
    """Debug endpoint - vulnerable to information disclosure"""
    return f"""
    <h1>Debug Information</h1>
    <p><strong>Environment Variables:</strong></p>
    <pre>{json.dumps(dict(os.environ), indent=2)}</pre>
    <p><strong>Request Headers:</strong></p>
    <pre>{json.dumps(dict(request.headers), indent=2)}</pre>
    <p><strong>Database Config:</strong></p>
    <pre>{json.dumps(DB_CONFIG, indent=2)}</pre>
    <p><a href="/">Back to Home</a></p>
    """

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
