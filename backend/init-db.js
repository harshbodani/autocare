// Creates tables and seeds demo data. Safe to run repeatedly.
const fs = require('fs');
const path = require('path');
const pool = require('./db');
const { seed } = require('./seed');

async function initDb() {
    await pool.query(fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8'));
    const seeded = await seed(pool);
    console.log(seeded ? 'Schema ready and demo data inserted.' : 'Schema ready (existing data kept).');
}

module.exports = { initDb };

if (require.main === module) {
    initDb().then(() => pool.end()).catch((e) => { console.error('DB init failed:', e.message); process.exit(1); });
}
