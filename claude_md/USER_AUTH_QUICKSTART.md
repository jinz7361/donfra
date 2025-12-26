# 用户认证系统 - 快速启动指南

## 🚀 快速开始

### 1. 启动数据库（会自动创建 users 表）

```bash
# 停止旧的容器并重新启动（会运行迁移脚本）
cd /home/don/donfra
make localdev-down
make localdev-up
```

数据库启动时会自动执行：
- `001_create_users_table.sql` - 创建 users 表
- `002_seed_lessons.sql` - 创建 lessons 表并填充数据

### 2. 验证 API 启动

```bash
# 检查服务状态
curl http://localhost:8080/healthz
# 应该返回: ok
```

### 3. 测试用户注册

```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@donfra.dev",
    "password": "testpass123",
    "username": "testuser"
  }'
```

**预期响应:**
```json
{
  "user": {
    "id": 2,
    "email": "test@donfra.dev",
    "username": "testuser",
    "role": "user",
    "isActive": true,
    "createdAt": "2024-12-16T..."
  }
}
```

### 4. 测试用户登录

```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -c cookies.txt \
  -d '{
    "email": "test@donfra.dev",
    "password": "testpass123"
  }'
```

**预期响应:**
```json
{
  "user": {
    "id": 2,
    "email": "test@donfra.dev",
    "username": "testuser",
    "role": "user",
    "isActive": true,
    "createdAt": "2024-12-16T..."
  },
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### 5. 测试获取当前用户

```bash
curl -X GET http://localhost:8080/api/auth/me \
  -b cookies.txt
```

**预期响应:**
```json
{
  "user": {
    "id": 2,
    "email": "test@donfra.dev",
    "username": "testuser",
    "role": "user",
    "isActive": true,
    "createdAt": "2024-12-16T..."
  }
}
```

### 6. 使用预设的管理员账号登录

数据库迁移脚本已经创建了一个管理员账号：

```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -c admin-cookies.txt \
  -d '{
    "email": "admin@donfra.dev",
    "password": "admin123"
  }'
```

## 📊 验证数据库

### 连接到数据库

```bash
# 使用 psql 连接
docker exec -it donfra-db psql -U donfra -d donfra_study
```

### 查看用户表

```sql
-- 查看所有用户
SELECT id, email, username, role, is_active, created_at FROM users;

-- 查看用户数量
SELECT COUNT(*) FROM users;

-- 检查管理员用户
SELECT * FROM users WHERE role = 'admin';
```

### 手动插入测试用户

```sql
-- 密码: test123 (bcrypt hash)
INSERT INTO users (email, password, username, role, is_active)
VALUES (
  'demo@donfra.dev',
  '$2a$12$N0ckZ3V7H7qG8yL3J.pRWOXhJZxF7g6wZKvXGLqKz7B8YhZmNVxmO',
  'demo',
  'user',
  true
);
```

## 🧪 完整测试流程脚本

创建一个测试脚本 `test-auth.sh`:

```bash
#!/bin/bash

API_BASE="http://localhost:8080/api"

echo "=== 1. 注册新用户 ==="
curl -X POST $API_BASE/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "alice@example.com",
    "password": "alice123456",
    "username": "alice"
  }'
echo -e "\n"

echo "=== 2. 登录 ==="
curl -X POST $API_BASE/auth/login \
  -H "Content-Type: application/json" \
  -c /tmp/cookies.txt \
  -d '{
    "email": "alice@example.com",
    "password": "alice123456"
  }'
echo -e "\n"

echo "=== 3. 获取当前用户信息 ==="
curl -X GET $API_BASE/auth/me \
  -b /tmp/cookies.txt
echo -e "\n"

echo "=== 4. 刷新 Token ==="
curl -X POST $API_BASE/auth/refresh \
  -b /tmp/cookies.txt \
  -c /tmp/cookies.txt
echo -e "\n"

echo "=== 5. 登出 ==="
curl -X POST $API_BASE/auth/logout \
  -b /tmp/cookies.txt
echo -e "\n"

echo "=== 6. 验证登出后无法访问 ==="
curl -X GET $API_BASE/auth/me \
  -b /tmp/cookies.txt
echo -e "\n"
```

运行测试：
```bash
chmod +x test-auth.sh
./test-auth.sh
```

## 🔍 调试技巧

### 查看 API 日志

```bash
docker logs donfra-api -f
```

关键日志信息：
- `[donfra-api] user service initialized` - 用户服务已初始化
- `[donfra-api] using Redis repository at redis:6379` - Redis 连接状态
- `[pubsub] Subscribed to room:headcount channel` - Pub/Sub 订阅成功

### 查看数据库日志

```bash
docker logs donfra-db -f
```

### 检查 Redis 连接

```bash
docker exec -it donfra-redis redis-cli ping
# 应该返回: PONG
```

### 解码 JWT Token

使用 [jwt.io](https://jwt.io) 或命令行：

```bash
# 安装 jq
# token="你的JWT token"
echo $token | cut -d. -f2 | base64 -d 2>/dev/null | jq
```

## ❌ 常见错误排查

### 错误: "email already exists"

**原因:** 邮箱已被注册

**解决:**
```sql
-- 删除测试用户
docker exec -it donfra-db psql -U donfra -d donfra_study -c "DELETE FROM users WHERE email='test@example.com';"
```

### 错误: "invalid or expired token"

**原因:** JWT token 已过期或无效

**解决:**
1. 重新登录获取新 token
2. 检查系统时间是否正确
3. 确认 JWT_SECRET 配置一致

### 错误: "password must be at least 8 characters"

**原因:** 密码太短

**解决:** 使用至少 8 个字符的密码

### 错误: "invalid email format"

**原因:** 邮箱格式不正确

**解决:** 使用有效的邮箱格式（例如：user@example.com）

### 数据库连接失败

```bash
# 检查数据库容器状态
docker ps | grep donfra-db

# 重启数据库
make localdev-restart-db

# 查看数据库日志
docker logs donfra-db
```

## 📁 重要文件位置

```
donfra/
├── donfra-api/
│   ├── internal/domain/user/     # 用户域逻辑
│   ├── internal/http/handlers/   # HTTP handlers
│   └── cmd/donfra-api/main.go    # 启动文件
├── infra/
│   ├── db/
│   │   ├── 001_create_users_table.sql  # 用户表迁移
│   │   └── seed_lessons.sql            # 课程数据
│   └── docker-compose.local.yml        # Docker 配置
└── claude_md/
    ├── USER_AUTH_API.md                # API 文档
    └── USER_AUTH_QUICKSTART.md         # 本文件
```

## 🎯 下一步

现在后端 API 已经完成，你可以：

1. ✅ 测试所有 API 端点
2. 📱 开始实现前端 UI（Next.js）
3. 🔐 集成到现有的 room/lessons 功能
4. 📧 添加邮箱验证功能
5. 🎨 实现用户资料页面

需要帮助实现 UI 部分吗？ 🚀
