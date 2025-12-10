# Donfra

![Go Version](https://img.shields.io/badge/go-1.24-blue.svg)
![Coverage](https://img.shields.io/badge/coverage-60%25-yellow.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

> 教育协作平台，支持实时代码编辑和 Python 执行

Educational/career mentorship platform with real-time collaborative coding capabilities, Python execution, and interactive whiteboarding.

## 📊 测试状态 (Test Status)

- ✅ 47 个单元测试 (47 unit tests)
- ✅ Handler 层覆盖率：~95% (Handler layer coverage)
- ✅ Domain 层覆盖率：~90% (Domain layer coverage)
- ✅ CI/CD 自动化测试 (Automated testing)

| 模块 (Module) | 测试数 (Tests) | 覆盖率 (Coverage) |
|------|--------|-----------|
| Handlers | 24 | ~95% |
| Auth Service | 12 | ~89% |
| Room Service | 11 | ~97% |
| **总计 (Total)** | **47** | **~60%** |

## 🚀 快速开始 (Quick Start)

### 本地开发 (Local Development)

```bash
# 启动所有服务 (Start all services)
make localdev-up

# 运行测试 (Run tests)
cd donfra-api
make test

# 查看覆盖率 (View coverage)
make test-coverage

# 停止所有服务 (Stop all services)
make localdev-down
```

### 测试命令 (Test Commands)

```bash
make test              # 快速测试 (Quick test)
make test-verbose      # 详细输出 (Verbose output)
make test-coverage     # 生成覆盖率 (Generate coverage)
make test-race         # 竞态检测 (Race detection)
make ci-test           # 完整 CI 测试 (Full CI test)
make lint              # 代码检查 (Lint code)
```

## 📁 项目结构 (Project Structure)

```
donfra/
├── donfra-api/          # Go REST API
│   ├── cmd/donfra-api/  # 入口点 (Entry point)
│   └── internal/
│       ├── domain/      # 业务逻辑 (Business logic) ✅ 有测试 (Tested)
│       │   ├── auth/    # JWT 认证 (JWT auth)
│       │   ├── room/    # 房间管理 (Room management)
│       │   ├── run/     # Python 执行 (Python execution)
│       │   └── study/   # 课程 CRUD (Lesson CRUD)
│       ├── http/        # HTTP 处理 (HTTP handlers) ✅ 有测试 (Tested)
│       │   ├── handlers/  # API 端点 (API endpoints)
│       │   ├── middleware/ # 中间件 (Middleware)
│       │   └── router/    # 路由 (Router)
│       └── pkg/         # 工具 (Utilities)
├── donfra-ws/           # WebSocket 服务器 (WebSocket server)
│   └── demo-server.js   # Yjs CRDT 协作 (Yjs CRDT collaboration)
├── donfra-ui/           # Next.js 前端 (Next.js frontend)
│   ├── app/             # App Router 页面 (App Router pages)
│   │   ├── coding/      # 协作编辑器 (Collaborative editor)
│   │   ├── library/     # 课程库 (Lesson library)
│   │   └── admin-dashboard/ # 管理面板 (Admin panel)
│   └── components/      # React 组件 (React components)
└── .github/workflows/   # CI/CD 配置 (CI/CD config)
```

## 🧪 测试 (Testing)

### 测试覆盖 (Test Coverage)

每次 push 或 PR 时，GitHub Actions 会自动 (On every push/PR, GitHub Actions automatically):
- ✅ 运行所有 47 个测试 (Run all 47 tests)
- ✅ 进行代码质量检查 (Code quality checks with golangci-lint)
- ✅ 生成测试覆盖率报告 (Generate coverage reports)
- ✅ 运行竞态检测 (Run race detection)
- ✅ 执行集成测试 (Run integration tests)

查看 [CI_SETUP.md](CI_SETUP.md) 了解详情 (See CI_SETUP.md for details).

### 测试原则 (Testing Principles)

本项目采用测试金字塔结构 (This project follows the test pyramid):
- 80% 单元测试 (Unit tests) - Domain + Handler 层
- 15% 集成测试 (Integration tests)
- 5% 端到端测试 (E2E tests)

使用接口抽象便于测试 (Using interfaces for testability):
- Mock: 控制返回值 (Control return values)
- Spy: 记录调用信息 (Record call information)
- Fake: 简化实现 (Simplified implementation)

## 🏗️ 架构 (Architecture)

### 核心概念 (Core Concepts)

- **房间访问控制 (Room-Based Access)**: 单个房间，通过密码开启/关闭 (Single room with passcode-based open/close)
- **JWT 认证**: 生成邀请链接令牌 (Generate invite tokens)
- **Python 沙箱执行**: 5 秒超时，隔离执行 (5-second timeout, sandboxed execution)
- **CRDT 协作**: 使用 Yjs 实现无冲突编辑 (Conflict-free editing with Yjs)
- **课程管理**: PostgreSQL 存储 Markdown + Excalidraw (Lessons stored in PostgreSQL)

### 技术栈 (Tech Stack)

**后端 (Backend)**:
- Go 1.24
- Chi router v5.1.0
- GORM ORM
- JWT authentication
- Python 3 subprocess execution

**前端 (Frontend)**:
- Next.js 14 (App Router)
- React 18
- TypeScript 5.5.4 (strict mode)
- Monaco Editor 0.55.1
- Excalidraw 0.18.0
- Framer Motion 11.2.10

**实时协作 (Real-time)**:
- Yjs 13.6.27
- y-websocket
- y-monaco
- WebSocket (ws library)

**基础设施 (Infrastructure)**:
- Docker & Docker Compose
- Caddy 2 reverse proxy
- PostgreSQL 16

## 📚 文档 (Documentation)

- [测试指南 (Testing Guide)](TESTING_RECOMMENDATIONS.md) - 完整测试路线图
- [CI 设置 (CI Setup)](CI_SETUP.md) - CI/CD 配置说明
- [接口测试价值 (Interface Testing)](WHY_INTERFACES_FOR_TESTING.md) - 为什么用接口测试
- [Domain 测试 (Domain Testing)](DOMAIN_TESTING_SUMMARY.md) - Domain 层测试重要性
- [项目指南 (Project Guide)](CLAUDE.md) - Claude Code 项目说明

## 🔧 开发命令 (Development Commands)

### API 开发 (API Development)

```bash
cd donfra-api

# 本地运行 (Run locally - requires Go 1.24+, Python3)
make run              # or: go run ./cmd/donfra-api

# 构建 (Build binary)
make build            # outputs to ./bin/donfra-api

# 格式化代码 (Format code)
make format           # go fmt ./...

# 清理 (Clean)
make clean
```

### UI 开发 (UI Development)

```bash
cd donfra-ui

# 开发服务器 (Development server)
npm run dev           # http://localhost:3000

# 生产构建 (Production build)
npm run build
npm run start
```

### WebSocket 开发 (WebSocket Development)

```bash
cd donfra-ws

# 启动 (Start - requires Node.js 16+)
npm start             # port 6789

# Docker 操作 (Docker operations)
make up               # docker-compose up -d --build
make down
make logs
```

## 🌐 API 端点 (API Endpoints)

所有路径通过 `/api` 或 `/api/v1` 访问 (All paths accessible via `/api` or `/api/v1`):

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/room/init` | 开启房间 (Open room - requires passcode) |
| GET | `/room/status` | 检查房间状态 (Check room status) |
| POST | `/room/join` | 加入房间 (Join room - requires token) |
| POST | `/room/close` | 关闭房间 (Close room) |
| POST | `/run` | 执行 Python 代码 (Execute Python code) |
| GET/POST | `/lessons` | 课程 CRUD (Lesson CRUD) |
| GET | `/lessons/:slug` | 获取指定课程 (Get lesson by slug) |

## 🔒 环境变量 (Environment Variables)

### API (`donfra-api`)

```bash
ADDR=:8080                           # 监听地址 (Listen address)
PASSCODE=7777                        # 房间密码 (Room passcode)
ADMIN_PASS=7777                      # 管理员密码 (Admin password)
JWT_SECRET=don-secret                # JWT 签名密钥 (JWT secret)
DATABASE_URL=postgresql://...        # 数据库连接 (Database URL)
CORS_ORIGIN=http://localhost:3000    # CORS 源 (CORS origin)
BASE_URL=http://localhost:3000       # 前端 URL (Frontend URL)
```

### UI (`donfra-ui`)

```bash
NEXT_PUBLIC_API_BASE_URL=/api        # API 端点 (API endpoint)
NEXT_PUBLIC_COLLAB_WS=/yjs           # WebSocket 端点 (WebSocket endpoint)
```

## 📝 重要说明 (Important Notes)

- 房间状态是 **临时的** (Room state is **ephemeral**, resets on API restart)
- Python 执行是 **沙箱化的** (Python execution is **sandboxed** with 5-second timeout)
- 协作编辑状态是 **临时的** (Collaborative editing state is **ephemeral**)
- 只有课程内容持久化到数据库 (Only lesson content is persisted to PostgreSQL)
- 所有 CSS 在 `/donfra-ui/public/styles/main.css` (All CSS in single file)

## 📄 License

MIT
