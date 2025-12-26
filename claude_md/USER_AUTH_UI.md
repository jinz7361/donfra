# User Authentication UI Implementation

## Overview

完整的用户认证 UI 已成功实现，包括注册、登录、用户菜单和登出功能。UI 采用与现有设计一致的"Spy/Hacker"风格，使用纯 CSS（无 CSS-in-JS）。

## 实现的功能

### 1. 用户状态管理 (AuthContext)

**文件**: [donfra-ui/lib/auth-context.tsx](../donfra-ui/lib/auth-context.tsx)

- 使用 React Context API 管理全局用户状态
- 自动在页面加载时检查认证状态（调用 `/api/auth/me`）
- 提供 `login`, `register`, `logout` 方法
- 提供 `user` 对象和 `loading` 状态

**使用方法**:
```tsx
import { useAuth } from '@/lib/auth-context';

function MyComponent() {
  const { user, loading, login, logout } = useAuth();

  if (loading) return <div>Loading...</div>;

  return user ? (
    <div>Welcome {user.username}!</div>
  ) : (
    <button onClick={() => login(email, password)}>Login</button>
  );
}
```

### 2. API 集成

**文件**: [donfra-ui/lib/api.ts](../donfra-ui/lib/api.ts:106-117)

新增 `api.auth` 命名空间，包含以下方法：

```typescript
api.auth.register(email, password, username?) // 注册用户
api.auth.login(email, password)               // 登录
api.auth.logout()                              // 登出
api.auth.me()                                  // 获取当前用户信息
api.auth.refresh()                             // 刷新 token
```

所有请求自动包含 `credentials: 'include'` 以支持 Cookie 认证。

### 3. Sign In Modal (登录弹窗)

**文件**: [donfra-ui/components/auth/SignInModal.tsx](../donfra-ui/components/auth/SignInModal.tsx)

**功能**:
- 邮箱 + 密码登录表单
- 实时错误提示
- 加载状态 (loading spinner)
- "Sign Up" 切换链接
- 点击背景关闭弹窗
- ESC 键支持（通过 CSS backdrop）

**使用示例**:
```tsx
<SignInModal
  isOpen={showSignIn}
  onClose={() => setShowSignIn(false)}
  onSwitchToSignUp={() => {
    setShowSignIn(false);
    setShowSignUp(true);
  }}
/>
```

### 4. Sign Up Modal (注册弹窗)

**文件**: [donfra-ui/components/auth/SignUpModal.tsx](../donfra-ui/components/auth/SignUpModal.tsx)

**功能**:
- 邮箱 + 密码 + 用户名（可选）表单
- 密码最少 8 字符验证（前端 + 后端）
- 实时错误提示
- 加载状态
- "Sign In" 切换链接
- 点击背景关闭弹窗

### 5. Header 更新

**文件**: [donfra-ui/app/page.tsx](../donfra-ui/app/page.tsx:46-73)

**未登录状态** - 显示两个按钮:
```
[Home] [Mission Path] [Stories] [Contact] [Sign In] [Sign Up]
```

**已登录状态** - 显示用户菜单（固定在最右侧）:
```
[Home] [Mission Path] [Stories] [Contact]          Welcome, [username ▼]
```

**用户菜单内容**:
- "Welcome," 问候语（桌面端显示，移动端隐藏）
- 用户名/邮箱按钮
- 下拉菜单：
  - 用户邮箱
  - 用户角色 (user/admin)
  - "Sign Out" 按钮

### 6. Layout 集成

**文件**: [donfra-ui/app/layout.tsx](../donfra-ui/app/layout.tsx:1-2,19-20)

整个应用被 `<AuthProvider>` 包裹，所有页面都可以使用 `useAuth()` hook。

## 样式设计

**文件**: [donfra-ui/public/styles/main.css](../donfra-ui/public/styles/main.css:731-1033)

### 设计特点

1. **配色方案**:
   - 主色: `var(--brass)` - 黄铜金色 (#A98E64)
   - 背景: 深色渐变 (`rgba(26,33,30,0.98)` → `rgba(12,14,15,0.98)`)
   - 边框: `rgba(169,142,100,0.35)` - 半透明黄铜色

2. **字体**:
   - 标题: `'Orbitron'` - 科技感标题字体
   - 导航/按钮: `'Rajdhani'` - UI 字体
   - 输入框/正文: `'IBM Plex Mono'` - 等宽字体

3. **动画效果**:
   - 按钮 hover: 颜色过渡 + 背景渐变
   - Modal: 背景模糊 (`backdrop-filter: blur(8px)`)
   - 输入框 focus: 边框高亮 + 阴影效果

4. **响应式设计**:
   - 手机端: 按钮缩小，Modal 全宽
   - 平板端: 正常显示
   - 桌面端: 固定最大宽度 440px

### 关键 CSS 类

| 类名 | 用途 |
|------|------|
| `.nav-auth-btn` | 导航栏认证按钮（Sign In/Sign Up） |
| `.nav-auth-btn-primary` | 主要按钮样式（Sign Up） |
| `.user-menu` | 用户菜单容器 |
| `.user-button` | 用户名按钮 |
| `.user-dropdown` | 下拉菜单 |
| `.modal-backdrop` | Modal 背景遮罩 |
| `.modal-dialog` | Modal 对话框 |
| `.modal-header` | Modal 头部 |
| `.modal-body` | Modal 内容区 |
| `.form-group` | 表单组 |
| `.form-input` | 输入框 |
| `.modal-actions` | 按钮区域 |

## 文件结构

```
donfra-ui/
├── app/
│   ├── layout.tsx                  # ✅ 添加 AuthProvider
│   └── page.tsx                    # ✅ 更新 Header，集成认证 UI
├── components/
│   └── auth/
│       ├── SignInModal.tsx         # ✅ 新建 - 登录弹窗
│       └── SignUpModal.tsx         # ✅ 新建 - 注册弹窗
├── lib/
│   ├── api.ts                      # ✅ 更新 - 添加 auth API
│   └── auth-context.tsx            # ✅ 新建 - 认证上下文
└── public/styles/
    └── main.css                    # ✅ 更新 - 添加认证 UI 样式
```

## 用户流程

### 注册流程

1. 用户点击 Header 右上角 "Sign Up" 按钮
2. 打开 SignUpModal
3. 填写邮箱、密码、用户名（可选）
4. 点击 "Sign Up" → 调用 `api.auth.register()`
5. 后端返回用户信息 → 更新 `user` 状态
6. Modal 关闭 → Header 自动显示用户名

### 登录流程

1. 用户点击 Header 右上角 "Sign In" 按钮
2. 打开 SignInModal
3. 填写邮箱、密码
4. 点击 "Sign In" → 调用 `api.auth.login()`
5. 后端设置 `auth_token` Cookie → 更新 `user` 状态
6. Modal 关闭 → Header 自动显示用户名

### 登出流程

1. 用户点击用户名按钮 → 显示下拉菜单
2. 点击 "Sign Out" → 调用 `api.auth.logout()`
3. 后端清除 Cookie → `user` 状态设为 `null`
4. Header 自动显示 "Sign In" 和 "Sign Up" 按钮

## 页面加载时的认证检查

当用户刷新页面或首次访问时：

1. `AuthProvider` 自动调用 `api.auth.me()`
2. 如果 Cookie 有效 → 后端返回用户信息 → 设置 `user` 状态
3. 如果 Cookie 无效/过期 → 后端返回 401 → `user` 保持 `null`
4. Header 根据 `user` 状态显示对应 UI

## 错误处理

### 前端验证

- **邮箱格式**: HTML5 `type="email"` 自动验证
- **密码长度**: `minLength={8}` 前端验证

### 后端错误

所有 API 错误都会显示在 Modal 顶部的 `.alert` 区域：

```tsx
{error && <div className="alert">{error}</div>}
```

常见错误信息：
- `"email already exists"` - 邮箱已被注册
- `"invalid email or password"` - 登录失败
- `"password must be at least 8 characters"` - 密码太短
- `"authentication required"` - 未登录（访问受保护资源）

## 安全特性

1. **HttpOnly Cookie**: 前端无法通过 JS 读取 `auth_token`
2. **SameSite=Lax**: 防止 CSRF 攻击
3. **密码不回显**: API 响应中不包含密码字段
4. **自动过期**: JWT token 7 天后自动失效
5. **Loading 状态**: 防止重复提交

## 测试建议

### 本地测试

1. 启动服务：
```bash
make localdev-up
```

2. 访问 [http://localhost:3000](http://localhost:3000)

3. 测试场景：
   - ✅ 注册新用户
   - ✅ 登录已存在用户
   - ✅ 错误邮箱/密码
   - ✅ 刷新页面后仍保持登录
   - ✅ 登出后 Cookie 清除
   - ✅ 用户菜单显示正确信息

### 使用预设管理员账号

```bash
# 登录凭据
Email: admin@donfra.com
Password: admin123
```

## 浏览器兼容性

- ✅ Chrome/Edge (最新版)
- ✅ Firefox (最新版)
- ✅ Safari (最新版)
- ✅ 移动端浏览器

**注意**: `backdrop-filter: blur()` 在某些旧浏览器可能不支持，但不影响功能。

## 后续优化建议

### 功能增强

- [ ] "Remember Me" 选项（延长 Cookie 有效期）
- [ ] "Forgot Password" 流程
- [ ] 邮箱验证（发送验证链接）
- [ ] OAuth 登录（Google/GitHub）
- [ ] 用户资料页面

### UI 优化

- [ ] Modal 打开/关闭动画（Framer Motion）
- [ ] 表单验证实时提示（边输入边验证）
- [ ] 密码强度指示器
- [ ] "Show/Hide Password" 按钮

### 可访问性 (a11y)

- [ ] 键盘导航支持（Tab/Enter/ESC）
- [ ] ARIA 标签（屏幕阅读器）
- [ ] Focus trap（Modal 内部焦点循环）
- [ ] 错误信息 ARIA live region

## 相关文档

- [USER_AUTH_API.md](./USER_AUTH_API.md) - 后端 API 文档
- [USER_AUTH_QUICKSTART.md](./USER_AUTH_QUICKSTART.md) - 快速启动指南
- [COOKIE_EXPLANATION.md](./COOKIE_EXPLANATION.md) - Cookie 设置详解
