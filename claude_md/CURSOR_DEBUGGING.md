# Yjs Cursor 调试指南

## 问题：光标重影

### 已修复的问题

**原因**: CSS 选择器重复导致同一个光标被渲染多次

**修复前**:
```typescript
const selFor = (clientId: number) => {
  const headClass = `.yRemoteSelectionHead-${clientId}`;
  const headAttr  = `.yRemoteSelectionHead[data-clientid="${clientId}"]`;
  const root = `.editor-pane .monaco-editor`;
  return {
    head: `${root} ${headClass}, ${root} ${headAttr}`,  // ❌ 重复选择器
    // ...
  };
};
```

**修复后**:
```typescript
const selFor = (clientId: number) => {
  const root = `.editor-pane .monaco-editor`;
  return {
    head: `${root} .yRemoteSelectionHead-${clientId}`,  // ✅ 单一选择器
    body: `${root} .yRemoteSelection-${clientId}`,
    headLabel: `${root} .yRemoteSelectionHead-${clientId} .yRemoteSelectionHeadLabel`,
  };
};
```

## 测试步骤

### 1. 启动服务

```bash
cd /home/don/donfra
make localdev-up
```

### 2. 打开浏览器控制台

打开两个浏览器窗口，都打开开发者工具（F12）

### 3. Admin 创建房间

```bash
# Terminal
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -c cookies_admin.txt \
  -d '{"email": "admin@donfra.com", "password": "admin123"}'

curl -X POST http://localhost:8080/api/interview/init \
  -H "Content-Type: application/json" \
  -b cookies_admin.txt
```

复制返回的 `invite_link`

### 4. 用户加入房间

**浏览器 1** (Alice):
1. 登录为 alice: `http://localhost:3000`
2. 打开 invite link
3. **查看控制台日志**:
   ```
   [CodePad] Local awareness state set: {userName: "alice", color: "#e74c3c", ...}
   [CodePad] Provider status: connected
   [CodePad] WebSocket status changed: connected
   [CodePad] Sync status: synced
   [CodePad] Awareness states updated. Total peers: 1 [{name: "alice", ...}]
   [CodePad] MonacoBinding created with awareness. Current awareness states: 1
   ```

**浏览器 2** (Bob):
1. 登录为 bob
2. 打开同一个 invite link
3. **查看控制台日志** - 应该看到 2 个 peers

### 5. 检查光标显示

在浏览器 1 (Alice) 中:
- 在编辑器中移动光标
- 在浏览器 2 (Bob) 中应该看到 **Alice 的光标** (红色边框 + "alice" 标签)
- **检查**: 是否有重影？应该只有一个光标

在浏览器 2 (Bob) 中:
- 在编辑器中移动光标
- 在浏览器 1 (Alice) 中应该看到 **Bob 的光标** (蓝色边框 + "bob" 标签)
- **检查**: 是否有重影？应该只有一个光标

### 6. 检查选区高亮

在浏览器 1 (Alice) 中:
- 选中一段代码
- 在浏览器 2 (Bob) 中应该看到 **浅红色背景 + 红色边框**
- **检查**: 选区是否清晰？没有重叠？

在浏览器 2 (Bob) 中:
- 选中一段代码
- 在浏览器 1 (Alice) 中应该看到 **浅蓝色背景 + 蓝色边框**
- **检查**: 选区是否清晰？没有重叠？

## 调试控制台日志

### 正常日志示例

**Alice 加入房间**:
```
[CodePad] Local awareness state set: {userName: "alice", color: "#e74c3c", colorLight: "rgba(231, 76, 60, 0.25)"}
[CodePad] Provider status: connected
[CodePad] WebSocket status changed: connected
[CodePad] Sync status: synced
[CodePad] Awareness states updated. Total peers: 1
  [
    {name: "alice", color: "#e74c3c", colorLight: "rgba(231, 76, 60, 0.25)"}
  ]
[CodePad] MonacoBinding created with awareness. Current awareness states: 1
```

**Bob 加入后 (Alice 的控制台)**:
```
[CodePad] Awareness states updated. Total peers: 2
  [
    {name: "alice", color: "#e74c3c", colorLight: "rgba(231, 76, 60, 0.25)"},
    {name: "bob", color: "#3498db", colorLight: "rgba(52, 152, 219, 0.25)"}
  ]
```

### 问题日志示例

**❌ WebSocket 未连接**:
```
[CodePad] Provider status: disconnected
[CodePad] WebSocket status changed: disconnected
```
**解决**: 检查 donfra-ws 服务是否运行

**❌ Awareness states 始终为 1**:
```
[CodePad] Awareness states updated. Total peers: 1
[CodePad] Awareness states updated. Total peers: 1  // 应该是 2
```
**解决**: 检查两个用户是否在同一个 room_id

**❌ MonacoBinding 创建失败**:
```
Error: Cannot read property 'getText' of undefined
```
**解决**: 检查 Monaco editor 是否已正确加载

## 检查 DOM 元素

打开浏览器开发者工具 → Elements 标签

### 检查光标 DOM

```html
<!-- Alice 的光标 (在 Bob 的浏览器中) -->
<div class="yRemoteSelectionHead yRemoteSelectionHead-123456">
  <div class="yRemoteSelectionHeadLabel">alice</div>
</div>
```

**应该只有一个 `.yRemoteSelectionHead-{clientId}` 元素**

如果看到多个，说明有重影问题。

### 检查 CSS 样式

在 `<head>` 中查找:
```html
<style id="y-remote-style-{room_id}">
  .editor-pane .monaco-editor .yRemoteSelectionHead-123456 {
    border-left-color: #e74c3c !important;
    border-left-width: 3px !important;
    /* ... */
  }
</style>
```

**检查**:
- 每个 clientId 只应该有一组规则
- 不应该有重复的选择器

## 常见问题

### Q: 看到多个光标在同一位置

**原因**: CSS 选择器重复

**检查**: `<style id="y-remote-style-...">` 中是否有重复规则

**修复**: 已在最新代码中修复，重新构建 UI

### Q: 光标颜色不对

**检查**: 控制台中 `awareness.setLocalState` 的颜色值

**示例**:
```
{color: "#e74c3c", colorLight: "rgba(231, 76, 60, 0.25)"}
```

应该是预定义调色板中的 10 种颜色之一

### Q: 用户名显示为 "User-xxxx" 而不是真实用户名

**原因**: 用户未认证或 `/api/auth/me` 调用失败

**检查**: 控制台是否有错误日志

**解决**: 确保用户已登录并有有效的 `auth_token` cookie

### Q: 在线用户列表不更新

**检查**: 控制台日志 `[CodePad] Awareness states updated. Total peers: X`

**原因**: Awareness change 事件未触发

**解决**: 检查 WebSocket 连接状态

## 性能监控

### 检查 WebSocket 流量

开发者工具 → Network → WS 标签

应该看到:
- **连接**: `ws://localhost:3000/yjs/{room_id}`
- **消息类型**: Binary (Yjs sync protocol)
- **频率**: 用户编辑时发送

### 检查 CPU 使用

如果光标动画导致高 CPU:
- 检查是否有太多 CSS 动画同时运行
- 检查 DOM 元素数量是否过多

## 清理测试

测试完成后:

```bash
# 关闭所有房间
curl -X POST http://localhost:8080/api/interview/close \
  -b cookies_admin.txt \
  -d '{"room_id": "..."}'

# 清理 cookies
rm cookies_*.txt
```

## 下一步优化

如果光标仍有问题，可以考虑:

1. **禁用动画** (临时测试):
   ```css
   animation: none !important;
   ```

2. **增加日志** (调试):
   ```typescript
   awareness.on('update', (changes) => {
     console.log('[Awareness] Update:', changes);
   });
   ```

3. **检查 y-monaco 版本兼容性**:
   ```bash
   cd donfra-ui
   npm list y-monaco y-websocket yjs
   ```
