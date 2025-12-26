# Interview Room API 文档

## 概述

Interview Room API 是一个基于用户认证的面试房间管理系统，取代了之前基于密码的简单 room 系统。新系统具有以下特点：

- **用户所有权**: 每个房间都有一个所有者（创建者）
- **持久化存储**: 房间信息存储在 PostgreSQL 数据库中
- **权限控制**: **仅 Admin 用户**可以创建房间，普通用户只能通过邀请链接加入
- **邀请链接**: 通过 JWT token 生成安全的邀请链接
- **软删除**: 房间关闭后使用软删除，保留历史记录

## 数据库 Schema

### interview_rooms 表

```sql
CREATE TABLE interview_rooms (
    id SERIAL PRIMARY KEY,
    room_id VARCHAR(255) UNIQUE NOT NULL,
    owner_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    headcount INTEGER DEFAULT 0,
    code_snapshot TEXT DEFAULT '',
    invite_link VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL
);
```

**字段说明**:
- `id`: 主键，自增 ID
- `room_id`: 房间唯一标识符（32位十六进制字符串）
- `owner_id`: 房间所有者的用户 ID（外键关联 users 表）
- `headcount`: 当前房间人数
- `code_snapshot`: 代码快照（用于保存最后的代码状态）
- `invite_link`: 完整的邀请链接
- `created_at`: 创建时间
- `updated_at`: 更新时间
- `deleted_at`: 删除时间（软删除，NULL 表示未删除）

## API 端点

### 1. 初始化房间 (Create Room)

**端点**: `POST /api/interview/init`

**权限**: **仅 Admin 用户**（需要用户认证 Cookie: `auth_token`，且 `role=admin`）

**请求体**: 空（或者空 JSON `{}`）

**响应** (201 Created):
```json
{
  "room_id": "3f7a2c8b1e9d4f6a0c5b8e7d2a1f4c9b",
  "invite_link": "http://localhost:3000/coding?token=eyJhbGc...",
  "message": "Interview room created successfully"
}
```

**错误响应**:
- `401 Unauthorized`: User not authenticated
- `403 Forbidden`: Only admin users can create interview rooms
- `409 Conflict`: User already has an active room
- `500 Internal Server Error`: Failed to create room

**权限规则**:
- ✅ **Admin 用户** (`role=admin`): 可以创建房间
- ❌ **普通用户** (`role=user`): **不能**创建房间，只能通过邀请链接加入
- ⚠️ **每个用户同时只能拥有一个活跃房间**

### 2. 加入房间 (Join Room)

**端点**: `POST /api/interview/join`

**权限**: 公开（任何人持有有效 invite token 即可加入）

**请求体**:
```json
{
  "invite_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**响应** (200 OK):
```json
{
  "room_id": "3f7a2c8b1e9d4f6a0c5b8e7d2a1f4c9b",
  "message": "Successfully joined interview room"
}
```

**副作用**:
- 设置 `room_access` Cookie，值为 `room_id`
- Cookie 有效期: 24 小时
- Cookie 属性: `HttpOnly`, `SameSite=Lax`

**错误响应**:
- `400 Bad Request`: Missing invite_token
- `401 Unauthorized`: Invalid or expired invite token
- `404 Not Found`: Room not found or has been closed
- `500 Internal Server Error`: Failed to join room

### 3. 关闭房间 (Close Room)

**端点**: `POST /api/interview/close`

**权限**: 需要用户认证（Cookie: `auth_token`）

**请求体**:
```json
{
  "room_id": "3f7a2c8b1e9d4f6a0c5b8e7d2a1f4c9b"
}
```

**响应** (200 OK):
```json
{
  "room_id": "3f7a2c8b1e9d4f6a0c5b8e7d2a1f4c9b",
  "message": "Room closed successfully"
}
```

**副作用**:
- 清除 `room_access` Cookie
- 软删除房间（设置 `deleted_at` 字段）

**错误响应**:
- `400 Bad Request`: Missing room_id
- `401 Unauthorized`: User not authenticated
- `403 Forbidden`: Only room owner can close the room
- `404 Not Found`: Room not found
- `500 Internal Server Error`: Failed to close room

**权限规则**:
- ✅ 只有房间所有者（owner）可以关闭房间
- ❌ 其他用户尝试关闭会收到 403 错误

## 使用流程

### 场景 1: Admin 用户创建并管理房间

```bash
# 1. Login as admin user
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -c cookies.txt \
  -d '{
    "email": "admin@donfra.com",
    "password": "admin123"
  }'

# 2. Create room (only admin can do this)
curl -X POST http://localhost:8080/api/interview/init \
  -H "Content-Type: application/json" \
  -b cookies.txt

# Response:
# {
#   "room_id": "abc123...",
#   "invite_link": "http://localhost:3000/coding?token=eyJ...",
#   "message": "Interview room created successfully"
# }

# 3. Share invite link with participants

# 4. Close room when done
curl -X POST http://localhost:8080/api/interview/close \
  -H "Content-Type: application/json" \
  -b cookies.txt \
  -d '{
    "room_id": "abc123..."
  }'
```

### 场景 2: 普通用户加入房间

```bash
# 普通用户不能创建房间，只能通过邀请链接加入

# 1. Get invite link from admin user
# Example: http://localhost:3000/coding?token=eyJhbGc...

# 2. Join room using the invite token
curl -X POST http://localhost:8080/api/interview/join \
  -H "Content-Type: application/json" \
  -c cookies.txt \
  -d '{
    "invite_token": "eyJhbGc..."
  }'

# 3. room_access cookie is now set, can access collaborative features
```

### 场景 3: 参与者通过邀请链接加入

```bash
# Extract token from invite link
# http://localhost:3000/coding?token=eyJhbGc...

# Join room using token
curl -X POST http://localhost:8080/api/interview/join \
  -H "Content-Type: application/json" \
  -c cookies.txt \
  -d '{
    "invite_token": "eyJhbGc..."
  }'

# room_access cookie is now set
# Can now access collaborative coding features
```

## Invite Token 结构

Invite token 是一个 JWT，包含以下 claims：

```json
{
  "room_id": "3f7a2c8b1e9d4f6a0c5b8e7d2a1f4c9b",
  "sub": "interview_room",
  "exp": 1234567890,  // 24小时后过期
  "iss": "donfra-api"
}
```

**签名算法**: HS256
**密钥**: 使用与用户 JWT 相同的 `JWT_SECRET` 环境变量
**有效期**: 24 小时

## 与旧 Room API 的对比

| 特性 | 旧 Room API | 新 Interview Room API |
|------|------------|----------------------|
| 认证方式 | Passcode | User JWT (admin only) |
| 存储方式 | In-memory (Redis/Memory) | PostgreSQL (持久化) |
| 房间所有权 | 无 | 有（owner_id） |
| 权限控制 | 统一密码 | **仅 Admin 用户可创建** |
| 历史记录 | 无 | 有（软删除） |
| 并发房间 | 单个全局房间 | 每个用户一个房间 |
| 邀请方式 | JWT token | JWT token (相似) |
| 普通用户 | 可创建（有密码） | **只能加入** |

## 环境变量

确保以下环境变量已配置：

```bash
# 数据库连接
DATABASE_URL=postgres://user:pass@localhost:5432/donfra

# JWT 密钥（用于签名 invite token）
JWT_SECRET=your-secret-key

# Base URL（用于生成 invite link）
BASE_URL=http://localhost:3000
```

## 数据库迁移

运行以下 SQL 脚本来创建 `interview_rooms` 表：

```bash
psql $DATABASE_URL < infra/db/migrations/002_create_interview_rooms.sql
```

或者在应用启动时自动执行迁移（如果使用 GORM AutoMigrate）。

## 测试

使用提供的测试脚本测试所有功能：

```bash
./test-interview-api.sh
```

测试覆盖：
- ✅ Admin 用户创建房间
- ✅ 通过 invite token 加入房间
- ✅ 防止重复创建房间
- ✅ 房间所有者关闭房间
- ✅ 普通用户**不能**创建房间（返回 403）
- ✅ 错误处理和权限验证

## 常见问题 (FAQ)

### Q: 为什么要从旧的 Room API 迁移到新的 Interview Room API？

A: 新系统提供了更好的：
- 用户所有权和权限管理
- 持久化存储（不会因重启丢失数据）
- 多房间支持（每个用户可以有自己的房间）
- 历史记录和审计

### Q: Admin 用户和普通用户的区别是什么？

A:
- **Admin 用户**: 可以创建房间，拥有房间所有权
- **普通用户**: **不能创建房间**，只能通过邀请链接加入房间

### Q: 如果用户已经有活跃房间，还能创建新房间吗？

A: 不能。每个用户同时只能拥有一个活跃房间。必须先关闭现有房间，才能创建新房间。

### Q: Invite token 过期后怎么办？

A: 房间所有者需要重新生成邀请链接。建议在房间详情页面添加"重新生成邀请链接"功能。

### Q: 关闭的房间可以恢复吗？

A: 可以。房间使用软删除（设置 `deleted_at`），可以通过清除 `deleted_at` 字段来恢复。但目前 API 没有提供恢复接口。

## 相关文档

- [USER_AUTH_API.md](./USER_AUTH_API.md) - 用户认证 API
- [USER_AUTH_UI.md](./USER_AUTH_UI.md) - 用户认证 UI
- [ADMIN_DASHBOARD_USER_AUTH.md](./ADMIN_DASHBOARD_USER_AUTH.md) - Admin 权限系统
