/**
 * 登录 / 注册参数校验
 *
 * 规则来自《财务管家 PRD V1.0.1》3.2.1：
 * - 用户名：3-20 字符，仅中文、字母、数字、下划线
 * - 密码：6-20 字符
 * - 昵称：可选，最长 50 字符
 */

const USERNAME_PATTERN = /^[一-龥A-Za-z0-9_]{3,20}$/;
const PASSWORD_MIN_LENGTH = 6;
const PASSWORD_MAX_LENGTH = 20;
const NICKNAME_MAX_LENGTH = 50;

function normalizeUsername(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function normalizeNickname(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function validateRegister(body = {}) {
  const errors = [];
  const username = normalizeUsername(body.username);
  const password = typeof body.password === 'string' ? body.password : '';
  const nickname = normalizeNickname(body.nickname);

  if (!username) {
    errors.push('用户名不能为空');
  } else if (!USERNAME_PATTERN.test(username)) {
    errors.push('用户名需为 3-20 个中文、字母、数字或下划线');
  }

  if (password.length < PASSWORD_MIN_LENGTH || password.length > PASSWORD_MAX_LENGTH) {
    errors.push(`密码长度需为 ${PASSWORD_MIN_LENGTH}-${PASSWORD_MAX_LENGTH} 个字符`);
  }

  if (nickname.length > NICKNAME_MAX_LENGTH) {
    errors.push(`昵称不能超过 ${NICKNAME_MAX_LENGTH} 个字符`);
  }

  return {
    valid: errors.length === 0,
    errors,
    data: {
      username,
      password,
      nickname: nickname || username
    }
  };
}

function validateLogin(body = {}) {
  const errors = [];
  const username = normalizeUsername(body.username);
  const password = typeof body.password === 'string' ? body.password : '';

  if (!username) errors.push('用户名不能为空');
  if (!password) errors.push('密码不能为空');

  return {
    valid: errors.length === 0,
    errors,
    data: { username, password }
  };
}

module.exports = {
  validateRegister,
  validateLogin,
  USERNAME_PATTERN
};
