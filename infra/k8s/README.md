# Donfra Kubernetes Deployment

This directory contains Kubernetes manifests for deploying Donfra on a local Kind cluster.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

## Quick Start

### 1. Setup the Kind Cluster

```bash
cd infra/k8s
./setup-kind.sh
```

This script will:
- Create a Kind cluster with 1 control plane and 2 worker nodes
- Install NGINX Ingress Controller
- Build Docker images for donfra-api and donfra-ws
- Load images into Kind cluster
- Apply all Kubernetes manifests
- Wait for all pods to be ready

### 2. Configure /etc/hosts

Add this line to your `/etc/hosts` file:

```
127.0.0.1 donfra.local
```

### 3. Access the Application

Open your browser and navigate to:
- **Application**: http://donfra.local
- **Jaeger UI**: http://localhost:16686 (via port-forward, see below)

## Architecture

The deployment includes:

- **donfra-api** (2 replicas): Go REST API backend
- **donfra-ws** (2 replicas): Node.js WebSocket server for real-time collaboration
- **donfra-ui** (2 replicas): Next.js SSR frontend
- **PostgreSQL** (1 replica): Database with persistent storage
- **Redis** (1 replica): Shared state store with persistent storage
- **Jaeger** (1 replica): Distributed tracing

## Directory Structure

```
infra/k8s/
├── base/                           # Base Kubernetes manifests
│   ├── namespace.yaml              # donfra namespace
│   ├── postgres-*.yaml             # PostgreSQL resources
│   ├── redis-*.yaml                # Redis resources
│   ├── jaeger-*.yaml               # Jaeger resources
│   ├── api-*.yaml                  # donfra-api resources
│   ├── ws-*.yaml                   # donfra-ws resources
│   ├── ui-*.yaml                   # donfra-ui resources
│   └── ingress.yaml                # NGINX Ingress routing
├── kind-config.yaml                # Kind cluster configuration
├── setup-kind.sh                   # Setup script
├── teardown-kind.sh                # Teardown script
├── rebuild-images.sh               # Rebuild and reload images
└── logs.sh                         # View logs for a service
```

## Useful Commands

### View Pod Status

```bash
kubectl get pods -n donfra
```

### View All Resources

```bash
kubectl get all -n donfra
```

### View Logs

```bash
# Using the helper script
./logs.sh api    # View API logs
./logs.sh ws     # View WebSocket logs
./logs.sh ui     # View UI logs

# Or directly with kubectl
kubectl logs -f -n donfra <pod-name>
```

### Port Forwarding

```bash
# Access PostgreSQL
kubectl port-forward -n donfra svc/postgres 5432:5432

# Access Jaeger UI
kubectl port-forward -n donfra svc/jaeger 16686:16686

# Access Redis
kubectl port-forward -n donfra svc/redis 6379:6379
```

### Rebuild and Reload Images

If you make changes to the code:

```bash
./rebuild-images.sh
```

### Restart a Deployment

```bash
kubectl rollout restart deployment/api -n donfra
kubectl rollout restart deployment/ws -n donfra
kubectl rollout restart deployment/ui -n donfra
```

### Execute Commands in a Pod

```bash
# Connect to PostgreSQL
kubectl exec -it -n donfra <postgres-pod-name> -- psql -U donfra -d donfra_study

# Connect to Redis
kubectl exec -it -n donfra <redis-pod-name> -- redis-cli
```

### Delete the Cluster

```bash
./teardown-kind.sh
```

## Troubleshooting

### Pods Not Starting

Check pod events:
```bash
kubectl describe pod -n donfra <pod-name>
```

### Image Pull Errors

If images are not found, rebuild and reload:
```bash
./rebuild-images.sh
```

### Ingress Not Working

Check Ingress Controller status:
```bash
kubectl get pods -n ingress-nginx
```

View Ingress details:
```bash
kubectl describe ingress -n donfra donfra-ingress
```

### Database Connection Issues

Check PostgreSQL logs:
```bash
./logs.sh postgres
```

Verify database is ready:
```bash
kubectl exec -it -n donfra <postgres-pod-name> -- psql -U donfra -d donfra_study -c "SELECT 1;"
```

## Configuration

### Environment Variables

Configuration is managed through ConfigMaps and Secrets:

- **api-config**: API environment variables
- **api-secret**: JWT secret
- **ws-config**: WebSocket server configuration
- **ui-config**: UI environment variables
- **postgres-config**: PostgreSQL configuration
- **postgres-secret**: PostgreSQL password

To update configuration:

```bash
# Edit the ConfigMap or Secret
kubectl edit configmap api-config -n donfra

# Restart the deployment to pick up changes
kubectl rollout restart deployment/api -n donfra
```

### Scaling

Scale deployments up or down:

```bash
# Scale API to 3 replicas
kubectl scale deployment/api -n donfra --replicas=3

# Scale WS to 1 replica
kubectl scale deployment/ws -n donfra --replicas=1
```

## Production Considerations

For production deployments, consider:

1. **External Database**: Use a managed PostgreSQL service instead of in-cluster database
2. **External Redis**: Use a managed Redis service
3. **Persistent Volumes**: Configure appropriate storage classes and backup strategies
4. **Resource Limits**: Adjust resource requests/limits based on load
5. **Horizontal Pod Autoscaling**: Configure HPA for auto-scaling
6. **TLS/SSL**: Configure TLS certificates for HTTPS
7. **Monitoring**: Add Prometheus/Grafana for comprehensive monitoring
8. **Secrets Management**: Use external secrets management (e.g., HashiCorp Vault, AWS Secrets Manager)
9. **Network Policies**: Implement network policies for security
10. **Image Registry**: Use a private container registry

## Next Steps

To prepare for production deployment:

1. Create production overlays in `overlays/production/`
2. Configure external database connection
3. Set up proper secrets management
4. Configure TLS certificates
5. Set up CI/CD pipeline for automated deployments
6. Configure monitoring and alerting
7. Implement backup and disaster recovery strategies
