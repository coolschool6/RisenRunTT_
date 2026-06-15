const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'your_password_here',
  database: process.env.DB_NAME || 'rise_and_run_tt',
});

const JWT_SECRET = process.env.JWT_SECRET || 'rise_and_run_jwt_secret_key_2026';

function authMiddleware(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'No token provided' });
  }
  try {
    const decoded = jwt.verify(header.split(' ')[1], JWT_SECRET);
    req.user = decoded;
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

function adminMiddleware(req, res, next) {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Admin access required' });
  }
  next();
}

app.post('/api/auth/signup', async (req, res) => {
  try {
    const { name, email, password } = req.body;
    if (!name || !email || !password) {
      return res.status(400).json({ error: 'Name, email, and password are required' });
    }
    const existing = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Email already registered' });
    }
    const salt = await bcrypt.genSalt(10);
    const password_hash = await bcrypt.hash(password, salt);
    const result = await pool.query(
      'INSERT INTO users (name, email, password_hash) VALUES ($1, $2, $3) RETURNING id, name, email, role',
      [name, email, password_hash]
    );
    const user = result.rows[0];
    const token = jwt.sign({ id: user.id, name: user.name, email: user.email, role: user.role }, JWT_SECRET, { expiresIn: '7d' });
    res.status(201).json({ user, token });
  } catch (err) {
    console.error('Signup error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }
    const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }
    const user = result.rows[0];
    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }
    const token = jwt.sign({ id: user.id, name: user.name, email: user.email, role: user.role }, JWT_SECRET, { expiresIn: '7d' });
    res.json({ user: { id: user.id, name: user.name, email: user.email, role: user.role }, token });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

app.get('/api/events', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM events ORDER BY date ASC');
    res.json(result.rows);
  } catch (err) {
    console.error('Events fetch error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

app.post('/api/admin/events', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { title, date, time, venue, category, price, image_url } = req.body;
    if (!title || !date || !time || !venue || !category) {
      return res.status(400).json({ error: 'Title, date, time, venue, and category are required' });
    }
    const result = await pool.query(
      'INSERT INTO events (title, date, time, venue, category, price, image_url) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *',
      [title, date, time, venue, category, price || 0, image_url || '']
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Create event error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

app.put('/api/admin/events/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const { title, date, time, venue, category, price, image_url } = req.body;
    const result = await pool.query(
      'UPDATE events SET title=$1, date=$2, time=$3, venue=$4, category=$5, price=$6, image_url=$7 WHERE id=$8 RETURNING *',
      [title, date, time, venue, category, price || 0, image_url || '', id]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Event not found' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Update event error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

app.delete('/api/admin/events/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query('DELETE FROM events WHERE id = $1', [id]);
    res.json({ message: 'Event deleted' });
  } catch (err) {
    console.error('Delete event error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

app.post('/api/user/submit-proof', authMiddleware, async (req, res) => {
  try {
    const { event_id, submission_type, proof_url } = req.body;
    if (!event_id || !submission_type) {
      return res.status(400).json({ error: 'Event ID and submission type are required' });
    }
    const result = await pool.query(
      'INSERT INTO registrations (user_id, event_id, status, submission_type, proof_url) VALUES ($1, $2, $3, $4, $5) RETURNING *',
      [req.user.id, event_id, 'pending', submission_type, proof_url || '']
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Submit proof error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

app.get('/api/admin/registrations', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT r.id, r.status, r.submission_type, r.proof_url, r.created_at, u.name AS user_name, u.email AS user_email, e.title AS event_title FROM registrations r JOIN users u ON r.user_id = u.id JOIN events e ON r.event_id = e.id ORDER BY r.created_at DESC'
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Fetch registrations error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

app.patch('/api/admin/registrations/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    if (!['approved', 'rejected'].includes(status)) {
      return res.status(400).json({ error: 'Status must be approved or rejected' });
    }
    const result = await pool.query('UPDATE registrations SET status=$1 WHERE id=$2 RETURNING *', [status, id]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Registration not found' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Update registration error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`Rise & Run TT API running on port ${PORT}`);
});
