# 🏗️ Donfra UI 重构指南

## ✅ 已完成的工作

### Phase 1: CSS 修复与基础设施
- [x] 修复无效CSS值 (`place-items: left` → `place-items: start center`)
- [x] 统一字体加载（移除重复请求）
- [x] 添加移动端响应式断点 (768px, 480px)
- [x] 创建统一 Design Tokens (`styles/tokens.css`)

### Phase 2: 组件库与工具函数
- [x] 创建可复用UI组件 (Button, Card, Input)
- [x] 提取 Excalidraw 工具函数
- [x] 创建 Storage 工具函数
- [x] 创建格式化工具函数

---

## 📦 新建文件清单

```
donfra-ui/
├── styles/
│   └── tokens.css                        # Design tokens (颜色、字体、间距等)
├── components/
│   └── ui/
│       ├── index.ts                      # 统一导出
│       ├── Button.tsx                    # 按钮组件
│       ├── Button.module.css
│       ├── Card.tsx                      # 卡片组件
│       ├── Card.module.css
│       ├── Input.tsx                     # 输入框组件
│       └── Input.module.css
└── lib/
    └── utils/
        ├── index.ts                      # 工具函数统一导出
        ├── excalidraw.ts                 # Excalidraw 相关工具
        ├── storage.ts                    # LocalStorage 封装
        └── format.ts                     # 格式化工具
```

---

## 🚀 使用新架构

### 1. 使用 UI 组件

**旧代码（需要替换）：**
```tsx
// ❌ 使用内联样式和CSS类
<button className="btn-elegant" style={{padding: "10px 14px"}}>
  初始化房间
</button>
```

**新代码：**
```tsx
// ✅ 使用统一组件
import { Button } from '@/components/ui';

<Button variant="elegant" size="md">
  初始化房间
</Button>
```

### 2. 使用 Excalidraw 工具函数

**旧代码（需要替换）：**
```tsx
// ❌ 每个文件都定义一遍
const EMPTY_EXCALIDRAW = {
  elements: [],
  appState: {},
  files: null,
};

const sanitizeExcalidraw = (raw: any) => {
  if (!raw || typeof raw !== "object") return { ...EMPTY_EXCALIDRAW };
  return {
    elements: Array.isArray(raw.elements) ? raw.elements : [],
    appState: raw.appState && typeof raw.appState === "object" ? raw.appState : {},
    files: raw.files || null,
  };
};
```

**新代码：**
```tsx
// ✅ 从 utils 导入
import { EMPTY_EXCALIDRAW, sanitizeExcalidraw } from '@/lib/utils';

const diagram = sanitizeExcalidraw(rawData);
```

### 3. 使用 Storage 工具

**旧代码（需要替换）：**
```tsx
// ❌ 直接操作 localStorage，容易出错
const token = localStorage.getItem('admin_token');
localStorage.setItem('admin_token', JSON.stringify(newToken));
```

**新代码：**
```tsx
// ✅ 类型安全的封装
import { getStorageItem, setStorageItem, STORAGE_KEYS } from '@/lib/utils';

const token = getStorageItem<string>(STORAGE_KEYS.ADMIN_TOKEN, '');
setStorageItem(STORAGE_KEYS.ADMIN_TOKEN, newToken);
```

### 4. 使用 Design Tokens

**旧代码（需要替换）：**
```css
/* ❌ 硬编码颜色和间距 */
.my-component {
  background: #0F1211;
  color: #E9E9E7;
  padding: 24px;
  border-radius: 12px;
}
```

**新代码：**
```css
/* ✅ 使用 Design Tokens */
.my-component {
  background: var(--color-bg-secondary);
  color: var(--color-text-primary);
  padding: var(--space-6);
  border-radius: var(--radius-xl);
}
```

---

## 📝 迁移检查清单

### 需要重构的文件（按优先级）

#### 高优先级（重复代码多）
- [ ] `app/library/create/CreateLessonClient.tsx` - 使用 `EMPTY_EXCALIDRAW` 和 `sanitizeExcalidraw`
- [ ] `app/library/[slug]/edit/EditLessonClient.tsx` - 使用 `EMPTY_EXCALIDRAW` 和 `sanitizeExcalidraw`
- [ ] `app/library/[slug]/LessonDetailClient.tsx` - 使用 `EMPTY_EXCALIDRAW`

#### 中优先级（可以使用新组件）
- [ ] `app/admin-dashboard/page.tsx` - 可以使用 Button, Card, Input
- [ ] `app/library/page.tsx` - 可以使用 Button, Card
- [ ] `app/coding/page.tsx` - 可以使用 Button, Card, Input

#### 低优先级（可选优化）
- [ ] `components/CodePad.tsx` - 拆分成更小的组件
- [ ] `app/page.tsx` - 主页（如果需要）

---

## 🔧 迁移示例

### 示例 1: 重构 CreateLessonClient.tsx

**步骤 1: 导入工具函数**
```tsx
// 在文件顶部添加
import { EMPTY_EXCALIDRAW, sanitizeExcalidraw } from '@/lib/utils';
```

**步骤 2: 删除本地定义**
```tsx
// ❌ 删除这些行
const EMPTY_EXCALIDRAW = { ... };
const sanitizeExcalidraw = (raw: any) => { ... };
```

**步骤 3: 使用导入的函数**
```tsx
// ✅ 直接使用导入的工具函数
const excaliRef = useRef<any>(EMPTY_EXCALIDRAW);
excaliRef.current = sanitizeExcalidraw({ ... });
```

### 示例 2: 重构 admin-dashboard 使用新组件

**Before:**
```tsx
<button
  className="btn-elegant"
  style={{padding: "10px 14px"}}
  onClick={handleLogin}
>
  登录
</button>
```

**After:**
```tsx
import { Button } from '@/components/ui';

<Button
  variant="elegant"
  onClick={handleLogin}
>
  登录
</Button>
```

---

## 🎯 下一步计划

### Phase 3: 状态管理 (待开始)
1. 安装 Zustand: `npm install zustand`
2. 创建 stores:
   - `lib/store/useRoomStore.ts` - 房间状态
   - `lib/store/useAuthStore.ts` - 认证状态
   - `lib/store/useLessonStore.ts` - 课程状态
3. 重构现有组件使用 Zustand

### Phase 4: API 层重构 (待开始)
1. 统一 API 调用模式
2. 添加错误处理中间件
3. 添加 loading 状态管理
4. 创建 React Query/SWR 集成（可选）

---

## 💡 最佳实践

### 1. 组件设计
- ✅ 使用 TypeScript 接口定义 props
- ✅ 使用 CSS Modules 避免样式冲突
- ✅ 使用 forwardRef 支持 ref 传递
- ✅ 添加 displayName 便于调试

### 2. 样式管理
- ✅ 优先使用 Design Tokens
- ✅ 避免内联样式（除非必要）
- ✅ 使用响应式设计（mobile-first）
- ✅ 保持样式文件小而专注

### 3. 状态管理
- ✅ 本地状态用 useState
- ✅ 全局状态用 Zustand（即将实现）
- ✅ 服务器状态用 React Query（未来考虑）
- ✅ 避免 prop drilling

### 4. 代码组织
- ✅ 一个功能一个文件夹
- ✅ 相关文件放在一起
- ✅ 使用 index.ts 统一导出
- ✅ 避免循环依赖

---

## 📊 进度追踪

### Phase 1: 基础设施 ✅ 100%
- [x] CSS 修复
- [x] 字体优化
- [x] 响应式断点
- [x] Design Tokens

### Phase 2: 组件库 ✅ 70%
- [x] Button 组件
- [x] Card 组件
- [x] Input 组件
- [x] Excalidraw 工具
- [x] Storage 工具
- [x] Format 工具
- [ ] CodePad 重构
- [ ] Modal 组件
- [ ] 迁移现有页面

### Phase 3: 状态管理 ⏳ 0%
- [ ] 安装 Zustand
- [ ] 创建 stores
- [ ] 重构组件

### Phase 4: API 层 ⏳ 0%
- [ ] 统一 API 模式
- [ ] 错误处理
- [ ] Loading 状态

---

## 🤝 贡献指南

在继续重构时，请遵循以下步骤：

1. **创建功能分支**
2. **测试更改** - 确保不破坏现有功能
3. **使用新组件** - 优先使用 UI 组件库
4. **更新文档** - 记录重要更改
5. **提交清晰的 commit** - 说明做了什么

---

## 📞 获取帮助

如果在重构过程中遇到问题：

1. 查看本指南的示例
2. 检查 `components/ui/` 中的组件实现
3. 参考 `lib/utils/` 中的工具函数
4. 使用 TypeScript 类型提示

---

**最后更新**: 2025-12-09
**版本**: 1.0.0
