// Idempotent demo data. Only runs when the users table is empty.
const { hashPassword } = require('./security');

async function seed(pool) {
    const { rows } = await pool.query('SELECT COUNT(*)::int AS n FROM users');
    if (rows[0].n > 0) return false;

    await pool.query(
        "INSERT INTO users (name, email, password, role) VALUES ($1, $2, $3, 'ADMIN')",
        ['Admin User', 'admin@autocare.com', hashPassword('password')]
    );

    const { rows: c } = await pool.query('SELECT COUNT(*)::int AS n FROM customers');
    if (c[0].n > 0) return true;

    await pool.query(`
        INSERT INTO customers (id, name, phone, email, address) VALUES
          (1, 'John Doe', '9876543210', 'john@example.com', '123 Main St'),
          (2, 'Jane Smith', '8887776665', 'jane@example.com', '456 Oak St');
        INSERT INTO vehicles (id, customer_id, registration_no, make, model, year, fuel_type, vin) VALUES
          (1, 1, 'GJ-01-AB-1234', 'Toyota', 'Innova', 2022, 'Diesel', 'VIN123'),
          (2, 2, 'GJ-01-CD-5678', 'Honda', 'City', 2021, 'Petrol', 'VIN456');
        INSERT INTO bookings (id, customer_id, vehicle_id, service_type, booking_date, booking_time, status, notes) VALUES
          (1, 1, 1, 'Full Service', '2026-10-22', '10:00 AM', 'PENDING', 'Check brakes'),
          (2, 2, 2, 'Oil Change', '2026-10-23', '11:30 AM', 'CONFIRMED', '');
        INSERT INTO invoices (id, customer_id, vehicle_id, invoice_no, total, subtotal, discount, tax, status, service_date, items) VALUES
          (1, 1, 1, 'INV-001', 1200.00, 1000.00, 0, 200.00, 'PAID', '2026-10-10', '[{"name": "General Service", "price": 1000.0}]'),
          (2, 2, 2, 'INV-002', 850.00, 800.00, 50.00, 100.00, 'UNPAID', '2026-10-15', '[{"name": "Oil Change", "price": 800.0}]');
        INSERT INTO reminders (id, customer_id, vehicle_id, title, reminder_date, is_done) VALUES
          (1, 1, 1, 'Pollution Check', '2026-11-01', 0),
          (2, 2, 2, 'Insurance Renewal', '2026-11-10', 0);
    `);
    // Explicit ids were used above, so move each sequence past them.
    for (const t of ['customers', 'vehicles', 'bookings', 'invoices', 'reminders']) {
        await pool.query(`SELECT setval(pg_get_serial_sequence('${t}', 'id'), (SELECT MAX(id) FROM ${t}))`);
    }
    return true;
}

module.exports = { seed };
