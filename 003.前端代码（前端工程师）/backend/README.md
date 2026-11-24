# 财务管家后端 - 登录 / 注册

## 1. 技术栈

| 项目 | 选型 |
|------|------|
| 运行时 | Node.js 24（CommonJS） |
| Web 框架 | Express 4 |
| 数据库 | MySQL 8.x / 9.x（当前环境 9.7.0） |
| 数据库驱动 | `mysql2/promise` 连接池 |
| 密码加密 | `bcryptjs`（10 轮） |
| 身份认证 | `jsonwebtoken`（JWT，默认 7 天） |
| 配置 | `dotenv`（读取 `.env`） |

## 2. 目录结构

```text
backend/
├── server.js                     # 服务入口（原有业务接口 + 挂载认证路由）
├── .env                          # 端口、数据库、JWT 配置
├── package.json
├── src/
│   ├── config/
│   │   └── db.js                 # MySQL 连接池（全局单例）
│   ├── controllers/
│   │   └── authController.js     # 注册 / 登录 HTTP 控制器
│   ├── middleware/
│   │   └── errorHandler.js       # 全局错误处理
│   ├── routes/
│   │   └── authRoutes.js         # POST /api/register、/api/login
│   ├── services/
│   │   └── authService.js        # 认证业务逻辑与数据库事务
│   ├── utils/
│   │   └── jwt.js                # JWT 签发
│   └── validators/
│       └── authValidator.js      # 参数校验
└── tests/
    └── auth.e2e.js               # 登录 / 注册端到端测试
```

## 3. 启动方式

### 3.1 前置条件

1. MySQL 服务已启动；
2. 已执行 `004.数据库脚本（数据库管理员DBA）/init_database.sql`；
3. `.env` 中的 `DB_HOST`、`DB_PORT`、`DB_USER`、`DB_PASSWORD`、`DB_NAME` 与实际环境一致。

### 3.2 安装与运行

```bash
cd "003.前端代码（前端工程师）/backend"
npm install
npm start
```

启动成功输出：

```text
✅ 财务管家API服务已启动: http://localhost:3001
✅ 数据库连接成功
```

前端页面中的 `API_BASE` 为 `http://localhost:3001/api`，无需额外修改。

## 4. 接口说明

### 4.1 用户注册 `POST /api/register`

请求体：

```json
{
  "username": "zhangsan",
  "password": "Test123456",
  "nickname": "张三"
}
```

校验规则（来自 PRD V1.0.1）：

- `username`：3-20 字符，仅中文、字母、数字、下划线；
- `password`：6-20 字符；
- `nickname`：可选，最长 50 字符，缺省时使用用户名。

成功响应（HTTP 200）：

```json
{
  "success": true,
  "message": "注册成功",
  "data": {
    "userId": 1,
    "username": "zhangsan",
    "nickname": "张三",
    "token": "eyJhbGciOiJIUzI1NiIs..."
  }
}
```

服务端行为（单事务）：

1. 检查用户名是否已存在；
2. `bcrypt` 哈希密码；
3. 写入 `users`；
4. 创建默认账本 `ledgers`；
5. 按 `account_types` 创建默认账户：现金、微信支付、支付宝；
6. 签发 JWT。

错误响应：

| HTTP | 场景 | message |
|------|------|---------|
| 400 | 参数不合法 | 具体校验提示 |
| 409 | 用户名已存在 | 用户名已存在 |
| 500 | 服务器异常 | 服务器错误 |

### 4.2 用户登录 `POST /api/login`

请求体：

```json
{
  "username": "zhangsan",
  "password": "Test123456"
}
```

成功响应（HTTP 200）：

```json
{
  "success": true,
  "message": "登录成功",
  "data": {
    "userId": 1,
    "username": "zhangsan",
    "nickname": "张三",
    "avatarUrl": null,
    "theme": "light",
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "ledgers": [
      { "id": 1, "name": "默认账本", "description": "我的第一个账本", "is_default": 1 }
    ],
    "accounts": [
      { "id": 1, "name": "现金", "icon": "💵", "color": "#FFB7C5", "initial_balance": "0.00", "current_balance": "0.00" },
      { "id": 2, "name": "微信支付", "icon": "📱", "color": "#7DD3C0", "initial_balance": "0.00", "current_balance": "0.00" },
      { "id": 3, "name": "支付宝", "icon": "🟢", "color": "#FF8FA3", "initial_balance": "0.00", "current_balance": "0.00" }
    ]
  }
}
```

服务端行为：

1. 按用户名查询用户；
2. 使用 `bcrypt.compare` 校验密码；
3. 更新 `users.last_login_at`；
4. 查询账本与账户；
5. 签发 JWT。

错误响应：

| HTTP | 场景 | message |
|------|------|---------|
| 400 | 用户名或密码为空 | 具体校验提示 |
| 401 | 用户不存在或密码错误 | 用户名或密码错误（不区分具体原因） |
| 500 | 服务器异常 | 服务器错误 |

### 4.3 Token 验证 `GET /api/verify`

请求头：

```text
Authorization: Bearer <token>
```

成功返回当前用户基础信息，失败返回 401。

## 5. 安全设计

- 密码只以 `bcrypt` 哈希形式存储，数据库不存明文；
- 登录失败统一返回「用户名或密码错误」，避免泄露用户名是否存在；
- JWT 只包含 `userId`、`username`，不包含密码；
- 注册使用数据库事务，用户、账本、账户要么全部成功，要么全部回滚；
- 依赖用户名唯一索引兜底并发重复注册（`ER_DUP_ENTRY` → 409）；
- 生产环境务必修改 `.env` 中的 `JWT_SECRET`，并使用最小权限数据库账号。

## 6. 自动测试

终端 1 启动服务：

```bash
npm start
```

终端 2 运行测试：

```bash
npm run test:auth
```

测试覆盖 19 项断言：注册成功、token、数据库落库、bcrypt 哈希、默认账本、3 个默认账户、登录成功、最后登录时间、错误密码 401、重复用户名 409、用户名/密码长度校验、Token 验证、测试数据清理。

## 7. 说明

- 当前 `server.js` 仍保留账户、分类、交易、统计等其余接口；认证部分已抽离到 `src/` 并按路由模块挂载，后续可继续按同样结构拆分其他模块。
- 数据库设计详见 `004.数据库脚本（数据库管理员DBA）/README.md`。
- 当前脚本与 MySQL 8.x 兼容；本机实际使用 MySQL 9.7.0，已通过完整验证。
