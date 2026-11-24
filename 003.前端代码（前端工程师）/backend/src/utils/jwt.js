/**
 * JWT 工具
 *
 * token 载荷只放 userId / username，不存放密码等敏感信息。
 */
require('dotenv').config();
const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'finance-manager-jwt-secret-2026';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '7d';

function signToken(user) {
  return jwt.sign(
    { userId: user.id, username: user.username },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES_IN }
  );
}

module.exports = { signToken, JWT_SECRET, JWT_EXPIRES_IN };
