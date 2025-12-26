# Admin Dashboard - User Authentication Integration

## 概述

所有需要 Admin 权限的 API 端点现在支持两种认证方式：
1. **传统 Admin Token** - 通过 `/api/admin/login` 密码登录获取 admin token
2. **用户 JWT 认证** - 已登录且 role=admin 的用户可直接访问

### 受影响的 API 端点

| 端点 | 方法 | 功能 | 认证方式 |
|------|------|------|----------|
| `/api/room/close` | POST | 关闭 room | Admin Token 或 Admin User JWT |
| `/api/lessons` | POST | 创建 lesson | Admin Token 或 Admin User JWT |
| `/api/lessons/{slug}` | PATCH | 更新 lesson | Admin Token 或 Admin User JWT |
| `/api/lessons/{slug}` | DELETE | 删除 lesson | Admin Token 或 Admin User JWT |
| `/admin-dashboard` | 页面 | Admin 控制面板 | Admin Token 或 Admin User JWT |
| `/library` | 页面 | Lesson 库（CRUD 按钮） | Admin Token 或 Admin User JWT |
| `/library/{slug}` | 页面 | Lesson 详情（编辑/删除按钮） | Admin Token 或 Admin User JWT |
| `/library/create` | 页面 | 创建 Lesson 页面 | Admin Token 或 Admin User JWT |
| `/library/{slug}/edit` | 页面 | 编辑 Lesson 页面 | Admin Token 或 Admin User JWT |

## 实现的功能

### 1. 后端中间件更新

**文件**: [donfra-api/internal/http/middleware/admin.go](../donfra-api/internal/http/middleware/admin.go:87-126)

新增 `RequireAdminUser` 中间件，支持双重认证：

```go
// RequireAdminUser requires either:
// 1. Admin token via Authorization header (legacy admin login)
// 2. User JWT token with role=admin via Cookie (user authentication)
func RequireAdminUser(authSvc TokenValidator, userSvc UserAuthService) func(http.Handler) http.Handler
```

**认证逻辑**:
1. 首先检查 `Authorization: Bearer <admin_token>` header
2. 如果没有 admin token，检查 `auth_token` Cookie
3. 验证 Cookie 中的 JWT token 并确认 `role == "admin"`
4. 两种方式都失败则返回 401

### 2. 路由配置更新

**文件**: [donfra-api/internal/http/router/router.go](../donfra-api/internal/http/router/router.go:59-71)

所有需要 admin 权限的路由都已更新为使用 `RequireAdminUser` 中间件：

```go
// Room management
v1.With(middleware.RequireAdminUser(authSvc, userSvc)).Post("/room/close", h.RoomClose)

// Lesson CRUD operations
v1.With(middleware.RequireAdminUser(authSvc, userSvc)).Post("/lessons", h.CreateLessonHandler)
v1.With(middleware.RequireAdminUser(authSvc, userSvc)).Patch("/lessons/{slug}", h.UpdateLessonHandler)
v1.With(middleware.RequireAdminUser(authSvc, userSvc)).Delete("/lessons/{slug}", h.DeleteLessonHandler)
```

**支持的 Admin 路由**:
- `POST /api/room/close` - 关闭 room
- `POST /api/lessons` - 创建 lesson
- `PATCH /api/lessons/{slug}` - 更新 lesson
- `DELETE /api/lessons/{slug}` - 删除 lesson

### 3. 前端 Admin Dashboard 更新

**文件**: [donfra-ui/app/admin-dashboard/page.tsx](../donfra-ui/app/admin-dashboard/page.tsx:14-35)

**关键改动**:

```typescript
// 导入 useAuth hook
import { useAuth } from "@/lib/auth-context";

export default function AdminDashboard() {
  const { user, loading: authLoading } = useAuth();

  // 检查是否为 admin 用户
  const isUserAdmin = user?.role === "admin";

  // 用户已认证 = admin token 或 admin user
  const authed = Boolean(token) || isUserAdmin;

  // ... rest of component
}
```

**三种UI状态**:

1. **Loading** - 检查用户认证状态
```typescript
if (authLoading) {
  return <div>Loading...</div>;
}
```

2. **未认证** - 显示 Admin 密码登录界面
```typescript
if (!authed) {
  return <AdminLoginForm />;
}
```

3. **已认证** - 显示 Dashboard（admin token 或 admin user 都可以）
```typescript
return <AdminDashboard />;
```

### 4. 前端 Library Pages 更新

**更新的文件**:
- [donfra-ui/app/library/page.tsx](../donfra-ui/app/library/page.tsx) - 主列表页面
- [donfra-ui/app/library/[slug]/LessonDetailClient.tsx](../donfra-ui/app/library/[slug]/LessonDetailClient.tsx) - Lesson 详情页面
- [donfra-ui/app/library/create/CreateLessonClient.tsx](../donfra-ui/app/library/create/CreateLessonClient.tsx) - 创建 Lesson 页面
- [donfra-ui/app/library/[slug]/edit/EditLessonClient.tsx](../donfra-ui/app/library/[slug]/edit/EditLessonClient.tsx) - 编辑 Lesson 页面

**关键改动**:

所有 library 页面现在都使用 `useAuth()` hook 来检查用户是否为 admin：

```typescript
import { useAuth } from "@/lib/auth-context";

export default function LibraryComponent() {
  const { user } = useAuth();

  // 支持双重认证：user role=admin 或 admin token
  const isUserAdmin = user?.role === "admin";
  const adminToken = typeof window !== "undefined" ? localStorage.getItem("admin_token") : null;
  const isAdmin = isUserAdmin || Boolean(adminToken);

  return (
    <>
      {/* 普通内容对所有用户可见 */}

      {/* CRUD 按钮仅对 admin 可见 */}
      {isAdmin && (
        <button onClick={...}>Create/Edit/Delete</button>
      )}
    </>
  );
}
```

**按钮可见性控制**:

1. **Library 列表页** (`/library`):
   - "Create lesson" 按钮仅在 `isAdmin === true` 时显示

2. **Lesson 详情页** (`/library/{slug}`):
   - "Edit lesson" 按钮仅在 `isAdmin === true` 时显示
   - "Delete" 按钮仅在 `isAdmin === true` 时显示

3. **Create/Edit 页面**:
   - 页面本身可以访问（URL 直接访问）
   - 但 submit 操作会检查权限
   - 如果没有 admin 权限会显示错误信息

**API 调用更新**:

所有 API 调用现在都添加了 `credentials: 'include'` 以支持 Cookie 认证：

```typescript
const res = await fetch(`${API_ROOT}/lessons`, {
  headers,
  credentials: 'include'  // 允许发送 Cookie
});
```

## 使用场景

### 场景 1: 使用传统 Admin 密码登录

```bash
# 1. 访问 /admin-dashboard
# 2. 输入 admin 密码
# 3. 获得 admin token，保存在 localStorage
# 4. 使用 admin token 调用 /api/room/close
```

**API 请求**:
```http
POST /api/room/close
Authorization: Bearer <admin_token>
```

### 场景 2: 使用 Admin 用户账号登录

```bash
# 1. 在主页点击 "Sign In"
# 2. 使用 admin@donfra.com / admin123 登录
# 3. 用户 JWT token 保存在 Cookie (auth_token)
# 4. 直接访问 /admin-dashboard
# 5. 自动检测到 role=admin，显示 Dashboard
# 6. 调用 /api/room/close 时自动使用 Cookie 中的 JWT
```

**API 请求**:
```http
POST /api/room/close
Cookie: auth_token=<user_jwt_token>
```

## 技术细节

### Cookie vs Header 认证

| 认证方式 | Token 来源 | 传输方式 | 使用场景 |
|---------|-----------|---------|----------|
| Admin Token | `/api/admin/login` | `Authorization: Bearer` header | 传统 admin 密码登录 |
| User JWT | `/api/auth/login` | `Cookie: auth_token` | 用户认证系统登录 (role=admin) |

### 中间件认证顺序

```
1. 检查 Authorization header
   ├─ 有 admin token? → 验证 → 通过 ✓
   └─ 没有 → 继续下一步

2. 检查 auth_token Cookie
   ├─ 有 user JWT? → 验证 → role=admin? → 通过 ✓
   └─ 没有/role≠admin → 拒绝 ✗

3. 都没有 → 返回 401 Unauthorized
```

### JWT Token 格式

**Admin Token** (传统方式):
```json
{
  "sub": "admin",
  "exp": 1234567890,
  "iss": "donfra-api"
}
```

**User JWT** (用户认证):
```json
{
  "user_id": 1,
  "email": "admin@donfra.com",
  "role": "admin",
  "exp": 1234567890,
  "iat": 1234567890,
  "iss": "donfra-api",
  "sub": "1"
}
```

## 前端状态管理

```typescript
// Admin Dashboard 状态
const authed = Boolean(token) || isUserAdmin;

// token: localStorage 中的 admin token
// isUserAdmin: user?.role === "admin" (来自 AuthContext)
```

**状态转换**:

```
未登录 (authed=false)
  ├─ 输入 admin 密码 → token 存在 → authed=true
  └─ 用户登录 (admin role) → isUserAdmin=true → authed=true

已登录 (authed=true)
  ├─ 登出 (admin token) → token=null, isUserAdmin 不变
  └─ 登出 (user auth) → isUserAdmin=false, token 不变
```

## 测试步骤

### 测试传统 Admin 登录

```bash
# 1. 清除所有认证状态
localStorage.clear()
document.cookie = "auth_token=; expires=Thu, 01 Jan 1970 00:00:00 UTC;"

# 2. 访问 /admin-dashboard
# 应该看到: Admin Login 界面

# 3. 输入密码 (默认: 7777) 并登录
# 应该看到: Dashboard 界面

# 4. 点击 "Close Room" 按钮
# 应该成功调用 API
```

### 测试 Admin 用户登录

```bash
# 1. 清除所有认证状态
localStorage.clear()
document.cookie = "auth_token=; expires=Thu, 01 Jan 1970 00:00:00 UTC;"

# 2. 在主页点击 "Sign In"
# 3. 使用 admin 账号登录:
#    Email: admin@donfra.com
#    Password: admin123

# 4. 访问 /admin-dashboard
# 应该看到: Dashboard 界面 (无需输入 admin 密码)

# 5. 点击 "Close Room" 按钮
# 应该成功调用 API (使用 Cookie 中的 JWT)

# 6. 在 Network 面板查看请求
# 应该看到: Cookie: auth_token=...
```

### 测试非 Admin 用户访问

```bash
# 1. 注册一个普通用户
POST /api/auth/register
{
  "email": "user@test.com",
  "password": "password123"
}

# 2. 登录该用户
POST /api/auth/login

# 3. 访问 /admin-dashboard
# 应该看到: Admin Login 界面 (因为 role != "admin")

# 4. 尝试直接调用 /api/room/close
# 应该返回: 401 Unauthorized

# 5. 尝试创建 lesson
POST /api/lessons
# 应该返回: 401 Unauthorized
```

### 测试 Lesson CRUD 权限

```bash
# 1. 以 admin 用户登录
POST /api/auth/login
{
  "email": "admin@donfra.com",
  "password": "admin123"
}

# 2. 创建新 lesson (使用 Cookie 认证)
curl -X POST http://localhost:8080/api/lessons \
  -H "Content-Type: application/json" \
  -b cookies.txt \
  -d '{
    "slug": "test-lesson",
    "title": "Test Lesson",
    "markdown": "# Test Content",
    "excalidraw": {},
    "isPublished": true
  }'
# 应该成功: 返回 201 Created

# 3. 更新 lesson
curl -X PATCH http://localhost:8080/api/lessons/test-lesson \
  -H "Content-Type: application/json" \
  -b cookies.txt \
  -d '{
    "title": "Updated Title"
  }'
# 应该成功: 返回 200 OK

# 4. 删除 lesson
curl -X DELETE http://localhost:8080/api/lessons/test-lesson \
  -b cookies.txt
# 应该成功: 返回 200 OK

# 5. 登出后再次尝试创建 lesson
curl -X POST http://localhost:8080/api/auth/logout -b cookies.txt
curl -X POST http://localhost:8080/api/lessons \
  -H "Content-Type: application/json" \
  -d '{...}'
# 应该失败: 返回 401 Unauthorized
```

## API 兼容性

### 向后兼容

✅ **完全兼容** - 所有现有的 admin token 认证继续工作

```javascript
// 旧代码仍然可以正常工作
const closeRoom = async (adminToken) => {
  await fetch('/api/room/close', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${adminToken}`
    }
  });
};
```

### 新增功能

✅ **新增** - Admin 用户可以使用 Cookie 认证

```javascript
// 新方式: 使用 Cookie (自动发送)
const closeRoom = async () => {
  await fetch('/api/room/close', {
    method: 'POST',
    credentials: 'include' // 自动发送 Cookie
  });
};
```

## 安全考虑

1. **双重认证路径** - 提供灵活性，不降低安全性
2. **Cookie HttpOnly** - 防止 XSS 攻击读取 JWT
3. **Role 验证** - 必须 `role === "admin"` 才能访问
4. **Token 过期** - 两种 token 都有过期时间
   - Admin token: 服务器配置
   - User JWT: 7 天

## 常见问题

### Q: 如果我同时有 admin token 和 admin user，会使用哪个？

A: 中间件优先检查 admin token (Authorization header)。如果存在且有效，就使用 admin token。只有在没有 admin token 时才检查 user JWT Cookie。

### Q: Admin 用户登出后还能访问 Dashboard 吗？

A: 不能。登出会清除 `auth_token` Cookie，下次访问会显示 Admin Login 界面。

### Q: 可以同时登录多个 admin 用户吗？

A: Cookie 是单一的，一次只能保持一个用户的登录状态。但是可以在不同浏览器或隐私窗口中使用不同的账号。

### Q: 如何创建新的 admin 用户？

A:

**方法 1: 直接修改数据库**
```sql
UPDATE users SET role = 'admin' WHERE email = 'user@example.com';
```

**方法 2: 注册后升级**
```bash
# 1. 用户正常注册
POST /api/auth/register

# 2. 数据库中修改 role
UPDATE users SET role = 'admin' WHERE id = <user_id>;
```

## 前端组件权限总结

| 组件 | 路径 | Admin 可见功能 | 普通用户可见 |
|------|------|----------------|--------------|
| Library 列表 | `/library` | "Create lesson" 按钮 | 只能查看 published lessons |
| Lesson 详情 | `/library/{slug}` | "Edit lesson", "Delete" 按钮 | 只能查看内容 |
| Create 页面 | `/library/create` | 完整创建表单 | 可访问但提交时会失败 |
| Edit 页面 | `/library/{slug}/edit` | 完整编辑表单 | 可访问但提交时会失败 |
| Admin Dashboard | `/admin-dashboard` | 完整控制面板 | 显示登录界面 |

## 相关文档

- [USER_AUTH_API.md](./USER_AUTH_API.md) - 用户认证 API 文档
- [USER_AUTH_UI.md](./USER_AUTH_UI.md) - 用户认证 UI 文档
- [COOKIE_EXPLANATION.md](./COOKIE_EXPLANATION.md) - Cookie 设置详解
