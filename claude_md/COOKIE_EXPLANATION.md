# Cookie 设置详解

## 位置总结

Cookie 在 **3 个地方**设置，都在 [donfra-api/internal/http/handlers/user.go](../donfra-api/internal/http/handlers/user.go)：

### 1. 登录时设置 Cookie (第 71 行)

**文件:** `internal/http/handlers/user.go`

```go
// Login handles user login requests.
// POST /api/auth/login
func (h *Handlers) Login(w http.ResponseWriter, r *http.Request) {
    // ... 验证用户凭据 ...

    authenticatedUser, token, err := h.userSvc.Login(ctx, &req)
    // ... 错误处理 ...

    // 👇 在这里设置 Cookie！
    http.SetCookie(w, &http.Cookie{
        Name:     "auth_token",           // Cookie 名称
        Value:    token,                  // JWT token 值
        Path:     "/",                    // 整个网站可用
        MaxAge:   7 * 24 * 60 * 60,      // 7天过期（单位：秒）
        HttpOnly: true,                   // 防止 JavaScript 访问（防XSS）
        Secure:   false,                  // 生产环境应设为 true（需HTTPS）
        SameSite: http.SameSiteLaxMode,  // 防止 CSRF 攻击
    })

    // 返回响应（包含用户信息和token）
    httputil.WriteJSON(w, http.StatusOK, user.LoginResponse{
        User:  authenticatedUser.ToPublic(),
        Token: token, // token 也在响应体中（可选）
    })
}
```

**HTTP 响应头:**
```
Set-Cookie: auth_token=eyJhbGc...; Path=/; Max-Age=604800; HttpOnly; SameSite=Lax
```

---

### 2. 登出时清除 Cookie (第 92 行)

```go
// Logout handles user logout requests.
// POST /api/auth/logout
func (h *Handlers) Logout(w http.ResponseWriter, r *http.Request) {
    // 👇 通过设置 MaxAge=-1 来删除 Cookie
    http.SetCookie(w, &http.Cookie{
        Name:     "auth_token",
        Value:    "",              // 空值
        Path:     "/",
        MaxAge:   -1,              // 立即删除！
        HttpOnly: true,
        Secure:   false,
        SameSite: http.SameSiteLaxMode,
    })

    httputil.WriteJSON(w, http.StatusOK, map[string]interface{}{
        "message": "logged out successfully",
    })
}
```

**HTTP 响应头:**
```
Set-Cookie: auth_token=; Path=/; Max-Age=-1; HttpOnly; SameSite=Lax
```

浏览器收到 `MaxAge=-1` 后会立即删除这个 Cookie。

---

### 3. 刷新 Token 时更新 Cookie (第 164 行)

```go
// RefreshToken refreshes the user's JWT token.
// POST /api/auth/refresh
func (h *Handlers) RefreshToken(w http.ResponseWriter, r *http.Request) {
    // ... 获取当前用户 ...

    // 生成新 token
    token, err := user.GenerateToken(currentUser, ...)

    // 👇 设置新的 Cookie（覆盖旧的）
    http.SetCookie(w, &http.Cookie{
        Name:     "auth_token",
        Value:    token,              // 新的 JWT token
        Path:     "/",
        MaxAge:   7 * 24 * 60 * 60,  // 重新设置7天
        HttpOnly: true,
        Secure:   false,
        SameSite: http.SameSiteLaxMode,
    })

    httputil.WriteJSON(w, http.StatusOK, map[string]interface{}{
        "token": token,
    })
}
```

---

## Cookie 参数详解

### Name: "auth_token"
- Cookie 的名称
- 浏览器和中间件都通过这个名称读取

### HttpOnly: true ⚠️ 重要！
- **防止 XSS 攻击**
- JavaScript 无法通过 `document.cookie` 读取
- 只能通过 HTTP 请求发送

### Secure: false (开发环境) / true (生产环境)
- `true`: 只能通过 HTTPS 发送
- `false`: HTTP 和 HTTPS 都可以
- **生产环境必须设为 true！**

### SameSite: Lax
- **防止 CSRF 攻击**
- `Lax`: 大多数跨站请求会发送 Cookie
- `Strict`: 只有同站请求发送 Cookie
- `None`: 所有请求都发送（需配合 Secure=true）

### Path: "/"
- Cookie 在整个网站下有效
- 如果设为 `/api`，则只在 API 路由下有效

### MaxAge: 604800 秒 = 7 天
- Cookie 的有效期
- 浏览器会自动在过期后删除
- `-1` = 立即删除

---

## 浏览器如何使用 Cookie

### 1. 用户登录

**请求:**
```http
POST /api/auth/login
Content-Type: application/json

{"email": "user@example.com", "password": "password123"}
```

**响应:**
```http
HTTP/1.1 200 OK
Set-Cookie: auth_token=eyJhbGc...; Path=/; Max-Age=604800; HttpOnly; SameSite=Lax
Content-Type: application/json

{"user": {...}, "token": "eyJhbGc..."}
```

**浏览器行为:**
- 自动保存 Cookie
- 后续请求自动携带

---

### 2. 后续请求自动携带 Cookie

**请求:**
```http
GET /api/auth/me
Cookie: auth_token=eyJhbGc...
```

浏览器**自动**在请求头中添加 `Cookie` 字段！

---

### 3. 中间件验证 Cookie

```go
// middleware/user_auth.go
func RequireAuth(userSvc UserAuthService) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            // 👇 从请求中读取 Cookie
            cookie, err := r.Cookie("auth_token")
            if err != nil {
                httputil.WriteError(w, 401, "authentication required")
                return
            }

            // 验证 token
            claims, err := userSvc.ValidateToken(cookie.Value)
            if err != nil {
                httputil.WriteError(w, 401, "invalid token")
                return
            }

            // 将用户信息注入 context
            ctx := context.WithValue(r.Context(), "user_id", claims.UserID)
            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}
```

---

## 前端如何使用

### JavaScript Fetch API

```javascript
// 登录（Cookie 自动保存）
const login = async () => {
  const response = await fetch('/api/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    credentials: 'include', // 👈 重要！告诉浏览器发送和接收 Cookie
    body: JSON.stringify({
      email: 'user@example.com',
      password: 'password123'
    })
  });

  // Cookie 自动保存在浏览器中
  return await response.json();
};

// 获取当前用户（Cookie 自动发送）
const getCurrentUser = async () => {
  const response = await fetch('/api/auth/me', {
    credentials: 'include' // 👈 自动发送 Cookie
  });

  return await response.json();
};
```

**注意:** `credentials: 'include'` 是关键！

---

### Axios

```javascript
import axios from 'axios';

// 全局配置
axios.defaults.withCredentials = true;

// 登录
const login = async () => {
  const response = await axios.post('/api/auth/login', {
    email: 'user@example.com',
    password: 'password123'
  });

  return response.data;
};

// Cookie 会自动发送
const getCurrentUser = async () => {
  const response = await axios.get('/api/auth/me');
  return response.data;
};
```

---

## 在浏览器开发工具中查看 Cookie

### Chrome DevTools

1. 打开开发者工具 (F12)
2. Application 标签
3. 左侧 Cookies
4. 选择你的网站
5. 查看 `auth_token`

**显示内容:**
```
Name:     auth_token
Value:    eyJhbGc...
Domain:   localhost
Path:     /
Expires:  2024-12-23 (7 days)
HttpOnly: ✓
Secure:   ✗
SameSite: Lax
```

---

## CORS 配置（跨域）

如果前端和后端在不同域名，需要配置 CORS：

```go
// router/router.go
root.Use(cors.Handler(cors.Options{
    AllowedOrigins:   []string{"http://localhost:3000"},
    AllowedMethods:   []string{"GET", "POST", "OPTIONS"},
    AllowedHeaders:   []string{"Content-Type"},
    AllowCredentials: true, // 👈 允许发送 Cookie！
    MaxAge:           300,
}))
```

前端也要设置：
```javascript
fetch('/api/auth/login', {
  credentials: 'include' // 跨域请求发送 Cookie
})
```

---

## 安全最佳实践

1. ✅ **HttpOnly = true** - 防止 XSS
2. ✅ **Secure = true (生产)** - 只在 HTTPS 下发送
3. ✅ **SameSite = Lax** - 防止 CSRF
4. ✅ **短期有效** - 7天自动过期
5. ✅ **HTTPS only (生产)** - 防止中间人攻击

---

## 总结

| 操作 | 端点 | Cookie 操作 | 行号 |
|------|------|------------|------|
| 登录 | POST /api/auth/login | 设置 Cookie | 71 |
| 登出 | POST /api/auth/logout | 删除 Cookie (MaxAge=-1) | 92 |
| 刷新 | POST /api/auth/refresh | 更新 Cookie | 164 |
| 访问受保护资源 | GET /api/auth/me | 读取 Cookie | middleware |

Cookie 是**自动管理**的：
- 浏览器自动保存
- 浏览器自动发送
- 后端通过 `http.SetCookie()` 设置
- 中间件通过 `r.Cookie()` 读取
