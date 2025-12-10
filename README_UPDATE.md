# 添加到 README.md 的内容

在你的主 README.md 文件顶部添加这些 badges：

```markdown
# Donfra

![Tests](https://github.com/你的用户名/donfra/workflows/Tests/badge.svg)
![Go Version](https://img.shields.io/badge/go-1.24-blue.svg)
![Coverage](https://img.shields.io/badge/coverage-60%25-yellow.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

> 教育协作平台，支持实时代码编辑和 Python 执行

## 📊 测试状态

- ✅ 47 个单元测试
- ✅ Handler 层覆盖率：~95%
- ✅ Domain 层覆盖率：~90%
- ✅ CI/CD 自动化测试

## 🚀 快速开始

### 本地开发

\`\`\`bash
# 启动所有服务
make localdev-up

# 运行测试
cd donfra-api
make test

# 查看覆盖率
make test-coverage
\`\`\`

### 测试命令

\`\`\`bash
make test              # 快速测试
make test-verbose      # 详细输出
make test-coverage     # 生成覆盖率
make test-race         # 竞态检测
make ci-test           # 完整 CI 测试
\`\`\`

## 📁 项目结构

\`\`\`
donfra/
├── donfra-api/          # Go REST API
│   ├── internal/
│   │   ├── domain/      # 业务逻辑（✅ 有测试）
│   │   └── http/        # HTTP 处理（✅ 有测试）
│   └── Makefile         # 测试命令
├── donfra-ws/           # WebSocket 服务器
├── donfra-ui/           # Next.js 前端
└── .github/workflows/   # CI/CD 配置
\`\`\`

## 🧪 测试

### 测试覆盖

| 模块 | 测试数 | 覆盖率 |
|------|--------|--------|
| Handlers | 24 | ~95% |
| Auth Service | 12 | ~90% |
| Room Service | 11 | ~96% |
| **总计** | **47** | **~60%** |

### CI/CD

每次 push 或 PR 时，GitHub Actions 会自动：
- ✅ 运行所有 47 个测试
- ✅ 进行代码质量检查（golangci-lint）
- ✅ 生成测试覆盖率报告
- ✅ 运行竞态检测
- ✅ 执行集成测试

查看 [CI_SETUP.md](CI_SETUP.md) 了解详情。

## 📚 文档

- [测试指南](TESTING_RECOMMENDATIONS.md) - 完整测试路线图
- [CI 设置](CI_SETUP.md) - CI/CD 配置说明
- [接口测试价值](WHY_INTERFACES_FOR_TESTING.md) - 为什么用接口测试
- [Domain 测试](DOMAIN_TESTING_SUMMARY.md) - Domain 层测试重要性
\`\`\`

---

## 可选：添加测试徽章

如果你使用 Codecov，可以添加：

\`\`\`markdown
[![codecov](https://codecov.io/gh/你的用户名/donfra/branch/main/graph/badge.svg)](https://codecov.io/gh/你的用户名/donfra)
\`\`\`

如果你使用 Go Report Card：

\`\`\`markdown
[![Go Report Card](https://goreportcard.com/badge/github.com/你的用户名/donfra)](https://goreportcard.com/report/github.com/你的用户名/donfra)
\`\`\`
