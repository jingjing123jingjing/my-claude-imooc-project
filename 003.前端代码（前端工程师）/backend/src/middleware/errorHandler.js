/**
 * 全局错误处理中间件
 *
 * 必须挂载在所有路由之后。5xx 不向客户端泄露内部细节。
 */
function errorHandler(error, req, res, next) {
  if (res.headersSent) {
    return next(error);
  }

  const status = error.status || 500;
  console.error(
    `[${new Date().toISOString()}] ${req.method} ${req.originalUrl} ->`,
    error.message
  );

  return res.status(status).json({
    success: false,
    message: status >= 500 ? '服务器错误' : error.message
  });
}

module.exports = errorHandler;
