# Donfra Kind Cluster Setup Guide

这个脚本会自动部署完整的 Donfra 平台，包括 Istio Ambient 模式和完整的可观测性栈。

## 前置条件

- Docker 正在运行
- Kind (Kubernetes in Docker) 已安装
- kubectl 已安装

## 快速开始

```bash
cd infra/k8s
bash setup-kind.sh
```

## 部署内容

### 1. Kubernetes 集群
- 使用 Kind 创建本地集群（3 个节点）
- 集群名称：`donfra-local`

### 2. Istio Ambient Mode
- Istio 1.28.1 with Ambient profile
- Gateway API (替代传统 Ingress)
- ztunnel for L4 mesh (无 sidecar)

### 3. 应用组件
- **donfra-api**: Go REST API (端口 8080)
- **donfra-ws**: WebSocket 服务器 (端口 6789)
- **donfra-ui**: Next.js 前端 (端口 3000)
- **PostgreSQL 16**: 数据库
- **Redis 7**: 缓存和 room 状态

### 4. 可观测性栈 (完整)
- **OpenTelemetry Collector**: 统一遥测收集
  - OTLP HTTP/gRPC 接收器
  - Prometheus exporter (端口 8889)
  - Jaeger exporter
  - Loki exporter

- **Prometheus**: 指标存储和查询
  - 15 秒抓取间隔
  - 自动服务发现
  - 抓取 OTel Collector 暴露的应用指标

- **Loki**: 日志聚合
  - 7 天保留期
  - 集成到 Grafana

- **Jaeger**: 分布式追踪
  - All-in-one 部署
  - OTLP HTTP 接收器

- **Grafana**: 统一可视化
  - 预配置数据源 (Prometheus, Loki, Jaeger)
  - 自动加载 "Donfra Platform Overview" 仪表板
  - 匿名 Admin 访问（无需登录）

## 部署步骤

脚本自动执行以下步骤：

1. **创建 Kind 集群** (如果已存在则删除并重建)
2. **安装 Istio Ambient** (通过 install-istio-ambient.sh)
3. **构建 Docker 镜像**
   - donfra-api:dev
   - donfra-ws:dev
   - UI 从 Docker Hub 拉取
4. **加载镜像到 Kind**
5. **部署 Kubernetes 资源**
   - Namespace
   - 基础设施（PostgreSQL, Redis, Jaeger）
   - 可观测性栈（OTel, Prometheus, Loki, Grafana）
   - 应用（API, WS, UI）
   - Gateway API 路由
6. **配置 Gateway for Kind**
   - 添加 hostPort 映射 (80, 443)
   - 调度到 control-plane 节点（拥有端口映射）
   - 添加容忍度以允许在主节点运行
7. **等待所有 Pod 就绪**
   - PostgreSQL (120s)
   - Redis (60s)
   - 可观测性组件 (90s)
   - 应用 pods (120s)

## 访问地址

添加到 `/etc/hosts`:
```
127.0.0.1 donfra.local
```

访问 URLs:
- **应用**: http://donfra.local
- **Grafana**: http://donfra.local/grafana
- **Prometheus**: http://donfra.local/prometheus
- **Jaeger**: http://donfra.local/jaeger

## Grafana 仪表板

预配置的仪表板：**Donfra Platform Overview**

包含以下面板：
- Room Opens/Closes/Joins Total (统计)
- Code Executions Total (统计)
- Room Operations Rate (图表)
- Code Execution Rate (图表)
- HTTP Request Rate by Endpoint (图表)
- HTTP Request Duration P95/P50 (图表)
- Lessons Created Total (统计)
- API Pod Count (统计)
- Pod CPU Usage (图表)
- Pod Memory Usage (图表)

## 已埋点的指标

### 业务指标
- `donfra_room_opened_total` - 房间开启次数
- `donfra_room_closed_total` - 房间关闭次数
- `donfra_room_joins_total` - 用户加入次数
- `donfra_code_executions_total` - Python 代码执行次数
- `donfra_lessons_created_total` - 课程创建次数

### 自动埋点指标
- `donfra_http_server_request_duration_seconds` - HTTP 请求延迟
- `donfra_http_server_request_body_size_bytes` - 请求体大小
- `donfra_http_server_response_body_size_bytes` - 响应体大小
- `donfra_go_sql_connections_*` - 数据库连接池指标

## 常用命令

```bash
# 查看所有 pods
kubectl get pods -n donfra

# 查看特定 pod 日志
kubectl logs -f -n donfra <pod-name>

# 查看 Istio Gateway 状态
kubectl get gateway -n donfra

# 查看路由配置
kubectl get httproute -n donfra

# 查看 Prometheus targets
curl http://donfra.local/prometheus/targets

# 查询指标
curl 'http://donfra.local/prometheus/api/v1/query?query=donfra_room_opened_total'

# 删除集群
kind delete cluster --name donfra-local
```

## 故障排查

### Pod 未启动
```bash
kubectl describe pod -n donfra <pod-name>
kubectl logs -n donfra <pod-name>
```

### Gateway 未工作
```bash
kubectl get gateway -n donfra -o yaml
kubectl logs -n istio-system -l app=istio-ingressgateway

# 检查 Gateway deployment 是否在 control-plane 节点上
kubectl get pods -n donfra -l gateway.networking.k8s.io/gateway-name=donfra-gateway -o wide

# 如果在 worker 节点，需要重新应用 patch
kubectl patch deployment donfra-gateway-istio -n donfra --patch-file gateway-deployment-patch.yaml
```

### 指标未显示
```bash
# 检查 OTel Collector
kubectl logs -n donfra -l app=otel-collector

# 检查 Prometheus targets
kubectl logs -n donfra -l app=prometheus

# 手动查询
curl 'http://donfra.local/prometheus/api/v1/query?query=up'
```

### Grafana 仪表板空白
```bash
# 检查 Grafana 日志
kubectl logs -n donfra -l app=grafana | grep -i dashboard

# 检查数据源
curl http://donfra.local/grafana/api/datasources
```

## 架构图

```
┌─────────────────┐
│  donfra.local   │
└────────┬────────┘
         │
    ┌────▼─────┐
    │  Gateway │ (Istio)
    └────┬─────┘
         │
    ┌────┴──────────────┬──────────────┬───────────┐
    ▼                   ▼              ▼           ▼
┌───────┐          ┌─────────┐   ┌──────────┐  ┌─────────┐
│  UI   │          │ Grafana │   │Prometheus│  │ Jaeger  │
└───┬───┘          └────┬────┘   └────┬─────┘  └────┬────┘
    │                   │             │             │
┌───▼───────────────┐   └─────────────┴─────────────┘
│  API  │  WS       │                 │
└───┬───┴───┬───────┘           ┌─────▼──────┐
    │       │                   │   OTel     │
┌───▼───┐ ┌─▼──┐               │ Collector  │
│ Redis │ │ DB │               └────────────┘
└───────┘ └────┘
```

## 清理

```bash
# 删除集群
kind delete cluster --name donfra-local

# 清理 Docker 镜像（可选）
docker rmi donfra-api:dev donfra-ws:dev
```

## 下一步

1. 访问应用: http://donfra.local
2. 查看 Grafana 仪表板: http://donfra.local/grafana
3. 测试房间功能以生成指标
4. 在 Prometheus 中查询自定义指标
5. 在 Jaeger 中查看分布式追踪

## 文档

- [Istio Ambient Setup](./ISTIO_AMBIENT_SETUP.md)
- [Observability Stack](../../OBSERVABILITY_STACK.md)
- [Grafana Dashboards](../../GRAFANA_DASHBOARDS.md)
- [Metrics Setup](../../METRICS_SETUP_COMPLETE.md)
