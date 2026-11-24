/**
 * 认证业务逻辑
 *
 * - registerUser：创建用户 + 默认账本 + 默认账户（单事务）
 * - loginUser：校验密码、更新最后登录时间、返回用户附属数据
 */
const bcrypt = require('bcryptjs');
const pool = require('../config/db');

const BCRYPT_ROUNDS = 10;
const DEFAULT_ACCOUNTS = ['现金', '微信支付', '支付宝'];
const DEFAULT_LEDGER_NAME = '默认账本';
const DEFAULT_LEDGER_DESCRIPTION = '我的第一个账本';

function createHttpError(status, message) {
  const error = new Error(message);
  error.status = status;
  return error;
}

/**
 * 注册用户
 * @param {{username: string, password: string, nickname: string}} payload
 * @returns {Promise<{id: number, username: string, nickname: string, ledgerId: number}>}
 */
async function registerUser({ username, password, nickname }) {
  const connection = await pool.getConnection();

  try {
    await connection.beginTransaction();

    const [existing] = await connection.execute(
      'SELECT id FROM users WHERE username = ? LIMIT 1',
      [username]
    );

    if (existing.length > 0) {
      throw createHttpError(409, '用户名已存在');
    }

    const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);
    const displayName = nickname || username;

    const [userResult] = await connection.execute(
      'INSERT INTO users (username, password, nickname) VALUES (?, ?, ?)',
      [username, passwordHash, displayName]
    );
    const userId = userResult.insertId;

    const [ledgerResult] = await connection.execute(
      'INSERT INTO ledgers (user_id, name, description, is_default) VALUES (?, ?, ?, 1)',
      [userId, DEFAULT_LEDGER_NAME, DEFAULT_LEDGER_DESCRIPTION]
    );
    const ledgerId = ledgerResult.insertId;

    // 根据账户类型字典创建默认账户（现金 / 微信支付 / 支付宝）
    const [types] = await connection.execute(
      'SELECT id, name, icon, color FROM account_types WHERE name IN (?, ?, ?)',
      DEFAULT_ACCOUNTS
    );
    const typeByName = new Map(types.map((type) => [type.name, type]));

    for (let index = 0; index < DEFAULT_ACCOUNTS.length; index += 1) {
      const accountName = DEFAULT_ACCOUNTS[index];
      const type = typeByName.get(accountName);
      if (!type) continue;

      await connection.execute(
        `INSERT INTO accounts
           (ledger_id, user_id, type_id, name, icon, color,
            initial_balance, current_balance, sort_order)
         VALUES (?, ?, ?, ?, ?, ?, 0, 0, ?)`,
        [ledgerId, userId, type.id, type.name, type.icon, type.color, index]
      );
    }

    await connection.commit();

    return { id: userId, username, nickname: displayName, ledgerId };
  } catch (error) {
    await connection.rollback();

    // 并发注册时唯一索引兜底
    if (error.code === 'ER_DUP_ENTRY') {
      throw createHttpError(409, '用户名已存在');
    }
    throw error;
  } finally {
    connection.release();
  }
}

/**
 * 用户登录
 * @param {{username: string, password: string}} payload
 * @returns {Promise<{user: object, ledgers: object[], accounts: object[]}>}
 */
async function loginUser({ username, password }) {
  const [rows] = await pool.execute(
    `SELECT id, username, password, nickname, avatar_url, theme
       FROM users
      WHERE username = ?
      LIMIT 1`,
    [username]
  );

  if (rows.length === 0) {
    throw createHttpError(401, '用户名或密码错误');
  }

  const user = rows[0];
  const passwordMatched = await bcrypt.compare(password, user.password);

  if (!passwordMatched) {
    throw createHttpError(401, '用户名或密码错误');
  }

  await pool.execute(
    'UPDATE users SET last_login_at = NOW() WHERE id = ?',
    [user.id]
  );

  const [ledgers] = await pool.execute(
    `SELECT id, name, description, is_default
       FROM ledgers
      WHERE user_id = ?
      ORDER BY is_default DESC, id ASC`,
    [user.id]
  );

  const [accounts] = await pool.execute(
    `SELECT id, name, icon, color, initial_balance, current_balance
       FROM accounts
      WHERE user_id = ?
      ORDER BY sort_order ASC, id ASC`,
    [user.id]
  );

  return {
    user: {
      id: user.id,
      username: user.username,
      nickname: user.nickname,
      avatarUrl: user.avatar_url,
      theme: user.theme || 'light'
    },
    ledgers,
    accounts
  };
}

module.exports = { registerUser, loginUser };
