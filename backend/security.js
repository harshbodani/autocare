// Password hashing and signed tokens using only Node's built-in crypto.
const crypto = require('crypto');

const SECRET = process.env.JWT_SECRET || crypto.randomBytes(32).toString('hex');
if (!process.env.JWT_SECRET) {
    console.warn('JWT_SECRET is not set; using a random one. Sessions will reset on every restart.');
}

function hashPassword(password) {
    const salt = crypto.randomBytes(16).toString('hex');
    const hash = crypto.scryptSync(password, salt, 64).toString('hex');
    return `scrypt$${salt}$${hash}`;
}

function verifyPassword(password, stored) {
    if (!stored || !stored.startsWith('scrypt$')) return false;
    const [, salt, hash] = stored.split('$');
    const test = crypto.scryptSync(password, salt, 64);
    const expected = Buffer.from(hash, 'hex');
    return expected.length === test.length && crypto.timingSafeEqual(expected, test);
}

const b64 = (b) => Buffer.from(b).toString('base64url');

function signToken(payload, ttlSeconds = 60 * 60 * 24 * 30) {
    const body = b64(JSON.stringify({ ...payload, exp: Math.floor(Date.now() / 1000) + ttlSeconds }));
    const sig = crypto.createHmac('sha256', SECRET).update(body).digest('base64url');
    return `${body}.${sig}`;
}

function verifyToken(token) {
    if (!token || !token.includes('.')) return null;
    const [body, sig] = token.split('.');
    const expected = crypto.createHmac('sha256', SECRET).update(body).digest('base64url');
    const a = Buffer.from(sig), b = Buffer.from(expected);
    if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return null;
    try {
        const data = JSON.parse(Buffer.from(body, 'base64url').toString());
        return data.exp > Math.floor(Date.now() / 1000) ? data : null;
    } catch (_) { return null; }
}

module.exports = { hashPassword, verifyPassword, signToken, verifyToken };
