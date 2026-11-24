/**
 * 认证控制器
 *
 * 负责参数校验、调用 service、组装 HTTP 响应。
 * 业务错误带 status 字段，交给当前控制器返回；
 * 未知错误交给全局错误处理中间件。
 */
const { registerUser, loginUser } = require('../services/authService');
const { validateRegister, validateLogin } = require('../validators/authValidator');
const { signToken } = require('../utils/jwt');

async function register(req, res, next) {
  try {
    const validation = validateRegister(req.body);

    if (!validation.valid) {
      return res.status(400).json({
        success: false,
        message: validation.errors[0],
        errors: validation.errors
      });
    }

    const user = await registerUser(validation.data);
    const token = signToken(user);

    return res.status(200).json({
      success: true,
      message: '注册成功',
      data: {
        userId: user.id,
        username: user.username,
        nickname: user.nickname,
        token
      }
    });
  } catch (error) {
    if (error.status) {
      return res.status(error.status).json({ success: false, message: error.message });
    }
    return next(error);
  }
}

async function login(req, res, next) {
  try {
    const validation = validateLogin(req.body);

    if (!validation.valid) {
      return res.status(400).json({
        success: false,
        message: validation.errors[0],
        errors: validation.errors
      });
    }

    const { user, ledgers, accounts } = await loginUser(validation.data);
    const token = signToken(user);

    return res.json({
      success: true,
      message: '登录成功',
      data: {
        userId: user.id,
        username: user.username,
        nickname: user.nickname,
        avatarUrl: user.avatarUrl,
        theme: user.theme,
        token,
        ledgers,
        accounts
      }
    });
  } catch (error) {
    if (error.status) {
      return res.status(error.status).json({ success: false, message: error.message });
    }
    return next(error);
  }
}

module.exports = { register, login };
