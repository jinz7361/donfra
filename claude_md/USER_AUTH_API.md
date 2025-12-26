# User Authentication API Documentation

## Overview

用户认证系统已成功实现，提供了完整的注册、登录、JWT 会话管理功能。

## 技术栈

- **密码加密**: bcrypt (cost=12)
- **JWT**: HS256 签名，7天有效期
- **会话管理**: HttpOnly Cookie
- **数据库**: PostgreSQL + GORM
- **架构**: 三层架构 (Repository → Service → Handler)

## API 端点

### 公开端点（无需认证）

#### 1. 用户注册

```http
POST /api/auth/register
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123",
  "username": "johndoe"  // 可选，默认使用邮箱前缀
}
```

**响应 (201 Created):**
```json
{
  "user": {
    "id": 1,
    "email": "user@example.com",
    "username": "johndoe",
    "role": "user",
    "isActive": true,
    "createdAt": "2024-12-16T10:30:00Z"
  }
}
```

**错误响应:**
- `400` - 邮箱格式无效 / 密码太短（至少8位）
- `409` - 邮箱已存在

#### 2. 用户登录

```http
POST /api/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123"
}
```

**响应 (200 OK):**
```json
{
  "user": {
    "id": 1,
    "email": "user@example.com",
    "username": "johndoe",
    "role": "user",
    "isActive": true,
    "createdAt": "2024-12-16T10:30:00Z"
  },
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**设置 Cookie:**
```
Set-Cookie: auth_token=<jwt_token>; Path=/; Max-Age=604800; HttpOnly; SameSite=Lax
```

**错误响应:**
- `401` - 邮箱或密码错误
- `403` - 账号未激活

#### 3. 用户登出

```http
POST /api/auth/logout
```

**响应 (200 OK):**
```json
{
  "message": "logged out successfully"
}
```

**清除 Cookie:**
```
Set-Cookie: auth_token=; Path=/; Max-Age=-1; HttpOnly; SameSite=Lax
```

### 受保护端点（需要认证）

这些端点需要在 Cookie 中携带有效的 `auth_token`。

#### 4. 获取当前用户信息

```http
GET /api/auth/me
Cookie: auth_token=<jwt_token>
```

**响应 (200 OK):**
```json
{
  "user": {
    "id": 1,
    "email": "user@example.com",
    "username": "johndoe",
    "role": "user",
    "isActive": true,
    "createdAt": "2024-12-16T10:30:00Z"
  }
}
```

**错误响应:**
- `401` - 未认证 / Token 无效或过期
- `404` - 用户不存在

#### 5. 刷新 Token

```http
POST /api/auth/refresh
Cookie: auth_token=<jwt_token>
```

**响应 (200 OK):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**设置新 Cookie:**
```
Set-Cookie: auth_token=<new_jwt_token>; Path=/; Max-Age=604800; HttpOnly; SameSite=Lax
```

## JWT Token 结构

```json
{
  "user_id": 1,
  "email": "user@example.com",
  "role": "user",
  "exp": 1734451200,
  "iat": 1733846400,
  "iss": "donfra-api",
  "sub": "1"
}
```

## 数据库 Schema

### users 表

```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,  -- bcrypt hash
    username VARCHAR(255),
    role VARCHAR(50) NOT NULL DEFAULT 'user',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ  -- 软删除
);
```

**索引:**
- `idx_users_email` on `email`
- `idx_users_username` on `username`
- `idx_users_deleted_at` on `deleted_at`

**默认用户:**
- Email: `admin@donfra.dev`
- Password: `admin123`
- Role: `admin`

## 使用示例

### cURL 示例

**注册新用户:**
```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "mypassword123",
    "username": "testuser"
  }'
```

**登录:**
```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -c cookies.txt \
  -d '{
    "email": "test@example.com",
    "password": "mypassword123"
  }'
```

**获取当前用户（使用保存的 cookie）:**
```bash
curl -X GET http://localhost:8080/api/auth/me \
  -b cookies.txt
```

**登出:**
```bash
curl -X POST http://localhost:8080/api/auth/logout \
  -b cookies.txt
```

### JavaScript/Fetch 示例

```javascript
// 注册
const register = async () => {
  const response = await fetch('/api/auth/register', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: 'user@example.com',
      password: 'password123',
      username: 'johndoe'
    })
  });
  const data = await response.json();
  return data;
};

// 登录
const login = async () => {
  const response = await fetch('/api/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    credentials: 'include',  // 重要：包含 cookies
    body: JSON.stringify({
      email: 'user@example.com',
      password: 'password123'
    })
  });
  const data = await response.json();
  return data;
};

// 获取当前用户
const getCurrentUser = async () => {
  const response = await fetch('/api/auth/me', {
    credentials: 'include'  // 重要：发送 cookies
  });
  const data = await response.json();
  return data;
};

// 登出
const logout = async () => {
  const response = await fetch('/api/auth/logout', {
    method: 'POST',
    credentials: 'include'
  });
  const data = await response.json();
  return data;
};
```

## 中间件使用

### RequireAuth - 强制认证

```go
// 只有认证用户才能访问
v1.With(middleware.RequireAuth(userSvc)).Get("/protected", handler)
```

### OptionalAuth - 可选认证

```go
// 认证用户和游客都能访问，但认证用户会有额外信息
v1.With(middleware.OptionalAuth(userSvc)).Get("/public", handler)
```

### RequireRole - 角色检查

```go
// 必须是指定角色（需配合 RequireAuth 使用）
v1.With(
  middleware.RequireAuth(userSvc),
  middleware.RequireRole("admin"),
).Post("/admin-only", handler)
```

### 从 Context 获取用户信息

```go
func YourHandler(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()

    // 获取用户 ID
    userID, ok := ctx.Value("user_id").(uint)

    // 获取用户邮箱
    email, ok := ctx.Value("user_email").(string)

    // 获取用户角色
    role, ok := ctx.Value("user_role").(string)
}
```

## 安全特性

1. **密码加密**: bcrypt cost=12
2. **HttpOnly Cookie**: 防止 XSS 攻击
3. **SameSite=Lax**: 防止 CSRF 攻击
4. **软删除**: 保留审计记录
5. **邮箱唯一性**: 数据库约束
6. **密码长度**: 最少 8 位
7. **JWT 过期**: 7 天自动过期

## 部署配置

确保在 `.env` 或环境变量中设置：

```bash
JWT_SECRET=your-secret-key-change-in-production
DATABASE_URL=postgres://user:pass@localhost:5432/dbname
```

## 文件清单

```
donfra-api/internal/
├── domain/user/
│   ├── model.go              # 用户模型和 DTO
│   ├── repository.go         # Repository 接口
│   ├── postgres_repository.go # PostgreSQL 实现
│   ├── service.go            # 业务逻辑
│   ├── password.go           # bcrypt 工具
│   └── jwt.go                # JWT 生成/验证
├── http/
│   ├── handlers/
│   │   ├── user.go           # 认证 handlers
│   │   └── handlers.go       # 更新接口
│   └── middleware/
│       └── user_auth.go      # JWT 认证中间件
└── http/router/
    └── router.go             # 路由配置

infra/db/
└── 001_create_users_table.sql # 数据库迁移
```

## 常见问题

### Q: 如何修改 Token 有效期？
A: 在 `main.go` 中修改：
```go
userSvc := user.NewService(userRepo, cfg.JWTSecret, 168) // 168小时=7天
```

### Q: 如何添加邮箱验证？
A: 在 `User` 模型添加 `EmailVerified bool` 字段，并创建验证流程。

### Q: 如何实现忘记密码？
A: 需要添加重置密码 token 和邮件发送功能。

### Q: 支持 OAuth 登录吗？
A: 当前不支持，需要额外实现 OAuth 流程。

## 下一步计划

- [ ] 邮箱验证
- [ ] 忘记密码/重置密码
- [ ] OAuth 集成（Google, GitHub）
- [ ] 用户资料更新
- [ ] 头像上传
- [ ] 权限管理（RBAC）
