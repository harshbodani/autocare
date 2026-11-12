const express = require('express');
const cors = require('cors');
require('dotenv').config();

const pool = require('./db');
const { initDb } = require('./init-db');
const { verifyPassword, hashPassword, signToken, verifyToken } = require('./security');

const app = express();
app.use(express.json({ limit: '1mb' }));
app.use(cors());

const wrap = (fn) => (req, res) => fn(req, res).catch((err) => {
    if (err.code === '23505') return res.status(400).json({ error: 'That record already exists (duplicate value).' });
    if (err.code === '23503') return res.status(400).json({ error: 'Related customer or vehicle was not found.' });
    if (err.code === '22P02' || err.code === '23502') return res.status(400).json({ error: 'Invalid or missing field value.' });
    console.error(err);
    res.status(500).json({ error: 'Server error.' });
});

// ---- Health (used by Render and to wake the free instance) ----
app.get('/health', wrap(async (req, res) => {
    await pool.query('SELECT 1');
    res.json({ ok: true });
}));

// ---- Auth ----
app.post('/api/auth/login', wrap(async (req, res) => {
    const { email, password } = req.body || {};
    if (!email || !password) return res.status(400).json({ error: 'Enter your email and password.' });
    const { rows } = await pool.query('SELECT * FROM users WHERE LOWER(email) = LOWER($1)', [String(email).trim()]);
    const user = rows[0];
    if (!user || !verifyPassword(String(password), user.password)) {
        return res.status(401).json({ error: 'Invalid email or password.' });
    }
    delete user.password;
    res.json({ token: signToken({ id: user.id, role: user.role }), user });
}));

app.post('/api/auth/register', wrap(async (req, res) => {
    const { name, email, password } = req.body || {};
    if (!name || !email || !String(email).includes('@') || !password || String(password).length < 4) {
        return res.status(400).json({ error: 'Enter a name, valid email and password (at least 4 characters).' });
    }
    const { rows } = await pool.query('SELECT 1 FROM users WHERE LOWER(email) = LOWER($1)', [String(email).trim()]);
    if (rows.length) return res.status(400).json({ error: 'An account with this email already exists.' });
    await pool.query(
        "INSERT INTO users (name, email, password, role) VALUES ($1, $2, $3, 'USER')",
        [String(name).trim(), String(email).trim(), hashPassword(String(password))]
    );
    res.json({ ok: true, message: 'User registered successfully' });
}));

// ---- Everything below requires a valid token ----
app.use('/api', (req, res, next) => {
    const h = req.headers.authorization || '';
    const claims = verifyToken(h.startsWith('Bearer ') ? h.slice(7) : '');
    if (!claims) return res.status(401).json({ error: 'Session expired. Please sign in again.' });
    req.user = claims;
    next();
});

app.get('/api/dashboard', wrap(async (req, res) => {
    const { rows } = await pool.query(`
        SELECT
          (SELECT COUNT(*) FROM customers)::int AS customers,
          (SELECT COUNT(*) FROM vehicles)::int AS vehicles,
          (SELECT COUNT(*) FROM bookings)::int AS bookings,
          (SELECT COUNT(*) FROM bookings WHERE status = 'PENDING')::int AS pending_bookings,
          (SELECT COUNT(*) FROM invoices WHERE status <> 'PAID')::int AS unpaid_invoices,
          COALESCE((SELECT SUM(total) FROM invoices WHERE status = 'PAID'), 0) AS revenue`);
    res.json(rows[0]);
}));

// ---- CRUD with an explicit column whitelist per table (no raw keys reach SQL) ----
const TABLES = {
    customers: {
        cols: ['name', 'phone', 'email', 'address'],
        list: 'SELECT * FROM customers ORDER BY id'
    },
    vehicles: {
        cols: ['customer_id', 'registration_no', 'make', 'model', 'year', 'fuel_type', 'vin'],
        list: 'SELECT v.*, c.name AS customer_name FROM vehicles v LEFT JOIN customers c ON v.customer_id = c.id ORDER BY v.id'
    },
    bookings: {
        cols: ['customer_id', 'vehicle_id', 'service_type', 'booking_date', 'booking_time', 'status', 'notes'],
        list: `SELECT t.*, c.name AS customer_name, v.registration_no FROM bookings t
               LEFT JOIN customers c ON t.customer_id = c.id LEFT JOIN vehicles v ON t.vehicle_id = v.id ORDER BY t.id`
    },
    invoices: {
        cols: ['customer_id', 'vehicle_id', 'invoice_no', 'subtotal', 'discount', 'tax', 'total', 'status', 'service_date', 'items'],
        list: `SELECT t.*, c.name AS customer_name, v.registration_no FROM invoices t
               LEFT JOIN customers c ON t.customer_id = c.id LEFT JOIN vehicles v ON t.vehicle_id = v.id ORDER BY t.id`
    },
    reminders: {
        cols: ['customer_id', 'vehicle_id', 'title', 'reminder_date', 'is_done'],
        list: `SELECT t.*, c.name AS customer_name, v.registration_no FROM reminders t
               LEFT JOIN customers c ON t.customer_id = c.id LEFT JOIN vehicles v ON t.vehicle_id = v.id ORDER BY t.id`
    }
};

const pick = (table, body) => {
    const data = {};
    for (const k of TABLES[table].cols) {
        if (body[k] !== undefined) data[k] = k === 'items' ? JSON.stringify(body[k]) : body[k];
    }
    return data;
};

for (const [table, cfg] of Object.entries(TABLES)) {
    app.get(`/api/${table}`, wrap(async (req, res) => {
        const { rows } = await pool.query(cfg.list);
        res.json(rows);
    }));

    app.post(`/api/${table}`, wrap(async (req, res) => {
        const data = pick(table, req.body || {});
        if (table === 'invoices') {
            data.total = (+data.subtotal || 0) - (+data.discount || 0) + (+data.tax || 0);
            data.invoice_no = 'TEMP-' + Date.now() + '-' + Math.floor(Math.random() * 1000);
        }
        const keys = Object.keys(data);
        const params = keys.map((_, i) => `$${i + 1}`).join(', ');
        const { rows } = await pool.query(
            `INSERT INTO ${table} (${keys.join(', ')}) VALUES (${params}) RETURNING id`,
            keys.map((k) => data[k])
        );
        const id = rows[0].id;
        if (table === 'invoices') {
            await pool.query('UPDATE invoices SET invoice_no = $1 WHERE id = $2', [`INV-${String(id).padStart(3, '0')}`, id]);
        }
        res.json({ ok: true, id });
    }));

    app.put(`/api/${table}/:id`, wrap(async (req, res) => {
        const data = pick(table, req.body || {});
        delete data.invoice_no;
        delete data.total;
        const keys = Object.keys(data);
        if (!keys.length) return res.status(400).json({ error: 'Nothing to update.' });
        const set = keys.map((k, i) => `${k} = $${i + 1}`).join(', ');
        await pool.query(`UPDATE ${table} SET ${set} WHERE id = $${keys.length + 1}`, [...keys.map((k) => data[k]), req.params.id]);
        if (table === 'invoices' && ['subtotal', 'discount', 'tax'].some((k) => k in data)) {
            await pool.query('UPDATE invoices SET total = subtotal - COALESCE(discount,0) + COALESCE(tax,0) WHERE id = $1', [req.params.id]);
        }
        res.json({ ok: true });
    }));

    app.delete(`/api/${table}/:id`, wrap(async (req, res) => {
        await pool.query(`DELETE FROM ${table} WHERE id = $1`, [req.params.id]);
        res.json({ ok: true });
    }));
}

app.put('/api/bookings/:id/status', wrap(async (req, res) => {
    await pool.query('UPDATE bookings SET status = $1 WHERE id = $2', [req.body.status, req.params.id]);
    res.json({ ok: true });
}));

app.put('/api/reminders/:id/done', wrap(async (req, res) => {
    await pool.query('UPDATE reminders SET is_done = $1 WHERE id = $2', [req.body.done ? 1 : 0, req.params.id]);
    res.json({ ok: true });
}));

app.get('/api/vehicles/:id/history', wrap(async (req, res) => {
    const { rows } = await pool.query('SELECT * FROM bookings WHERE vehicle_id = $1 ORDER BY id DESC', [req.params.id]);
    res.json(rows);
}));

const PORT = process.env.PORT || 3000;
initDb()
    .then(() => app.listen(PORT, '0.0.0.0', () => console.log(`AutoCare PostgreSQL backend running on port ${PORT}`)))
    .catch((e) => { console.error('Startup failed:', e.message); process.exit(1); });
