const { Pool, types } = require('pg');
require('dotenv').config();

// NUMERIC (1700) comes back as a string by default; the app expects numbers.
types.setTypeParser(1700, (v) => parseFloat(v));

const useSsl = process.env.DATABASE_SSL === 'true' ||
    (process.env.DATABASE_URL && !/localhost|127\.0\.0\.1/.test(process.env.DATABASE_URL) && process.env.DATABASE_SSL !== 'false');

const pool = new Pool(
    process.env.DATABASE_URL
        ? { connectionString: process.env.DATABASE_URL, ssl: useSsl ? { rejectUnauthorized: false } : false, max: 10 }
        : {
            host: process.env.DB_HOST || 'localhost',
            port: parseInt(process.env.DB_PORT || '5432', 10),
            user: process.env.DB_USER || 'postgres',
            password: process.env.DB_PASSWORD || '',
            database: process.env.DB_NAME || 'autocare_db',
            max: 10
        }
);

module.exports = pool;
