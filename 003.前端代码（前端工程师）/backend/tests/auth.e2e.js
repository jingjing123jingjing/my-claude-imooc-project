/**
 * 登录 / 注册端到端测试
 *
 * 前置条件：
 *   1. MySQL 已启动，且已执行 004 目录下的 init_database.sql
 *   2. 后端已启动：npm start
 *
 * 运行：node tests/auth.e2e.js
 */
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const mysql = require('mysql2/promise');

const BASE_URL = `http://localhost:${process.env.PORT || 3001}/api`;
const username = `auth_${String(Date.now()).slice(-8)}`;
const password = 'Test123456';
const nickname = '测试用户';

let passed = 0;
let failed = 0;
let userId = null;

function check(name, condition, detail = '') {
  if (condition) {
    passed += 1;
    console.log(`✅ ${name}${detail ? ` - ${detail}` : ''}`);
  } else {
    failed += 1;
    console.log(`❌ ${name}${detail ? ` - ${detail}` : ''}`);
  }
}

async function request(method, urlPath, body, token) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;

  const response = await fetch(BASE_URL + urlPath, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined
  });

  let json = null;
  try {
    json = await response.json();
  } catch {
    json = null;
  }

  return { status: response.status, body: json };
}

async function main() {
  console.log(`测试账号: ${username}\n`);

  // 1. 注册
  const register = await request('POST', '/register', { username, password, nickname });
  check(
    '注册接口返回成功',
    register.status === 200 && register.body?.success === true,
    `status=${register.status}`
  );
  check('注册返回 token', typeof register.body?.data?.token === 'string');
  userId = register.body?.data?.userId;
  check('注册返回 userId', Number.isInteger(userId));

  if (!userId) {
    console.log('\n注册失败，终止后续测试');
    process.exit(1);
  }

  const connection = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT) || 3306,
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || 'root',
    database: process.env.DB_NAME || 'finance_manager',
    charset: 'utf8mb4'
  });

  try {
    // 2. 数据库落库校验
    const [users] = await connection.execute(
      'SELECT id, username, nickname, password FROM users WHERE username = ?',
      [username]
    );
    check('用户已写入数据库', users.length === 1);
    check('密码以 bcrypt 哈希存储', users[0]?.password?.startsWith('$2') === true);
    check('昵称写入正确', users[0]?.nickname === nickname);

    const [ledgers] = await connection.execute(
      'SELECT id, name, is_default FROM ledgers WHERE user_id = ?',
      [userId]
    );
    check('自动创建默认账本', ledgers.length === 1 && ledgers[0].is_default === 1);

    const [accounts] = await connection.execute(
      'SELECT name FROM accounts WHERE user_id = ? ORDER BY sort_order',
      [userId]
    );
    check(
      '自动创建 3 个默认账户',
      accounts.length === 3,
      accounts.map((account) => account.name).join('、')
    );

    // 3. 登录
    const login = await request('POST', '/login', { username, password });
    check('登录接口返回成功', login.status === 200 && login.body?.success === true);
    check('登录返回 token', typeof login.body?.data?.token === 'string');
    check('登录返回 3 个账户', login.body?.data?.accounts?.length === 3);
    check('登录返回默认主题', login.body?.data?.theme === 'light');

    // 4. 最后登录时间
    const [afterLogin] = await connection.execute(
      'SELECT last_login_at FROM users WHERE id = ?',
      [userId]
    );
    check('更新最后登录时间', afterLogin[0]?.last_login_at !== null);

    // 5. 错误密码
    const wrong = await request('POST', '/login', { username, password: 'WrongPass123' });
    check('错误密码返回 401', wrong.status === 401 && wrong.body?.success === false);

    // 6. 重复注册
    const duplicate = await request('POST', '/register', { username, password, nickname });
    check('重复用户名返回 409', duplicate.status === 409 && duplicate.body?.success === false);

    // 7. 参数校验
    const shortUser = await request('POST', '/register', { username: 'ab', password });
    check('用户名过短返回 400', shortUser.status === 400);

    const shortPass = await request('POST', '/register', {
      username: `${username}x`,
      password: '123'
    });
    check('密码过短返回 400', shortPass.status === 400);

    // 8. Token 验证
    const verify = await request('GET', '/verify', null, login.body?.data?.token);
    check('Token 验证通过', verify.status === 200 && verify.body?.success === true);

    // 9. 清理测试数据（外键级联删除账本与账户）
    await connection.execute('DELETE FROM users WHERE id = ?', [userId]);
    const [left] = await connection.execute('SELECT id FROM users WHERE id = ?', [userId]);
    check('测试数据已清理', left.length === 0);
  } finally {
    await connection.end();
  }

  console.log(`\n结果: ${passed} 通过, ${failed} 失败`);
  process.exit(failed > 0 ? 1 : 0);
}

main().catch((error) => {
  console.error('测试执行失败:', error);
  process.exit(1);
});
