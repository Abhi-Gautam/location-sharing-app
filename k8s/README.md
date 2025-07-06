# Kubernetes Deployment Guide

This directory contains Kubernetes manifests and deployment scripts for the location sharing application's Elixir-only architecture.

## Quick Start

```bash
# Deploy Elixir backend with monitoring
./k8s/deploy.sh elixir deploy

# Check deployment status
./k8s/deploy.sh elixir status

# Delete all resources
./k8s/deploy.sh elixir delete
```

## Architecture Overview

### Infrastructure Components
- **PostgreSQL**: Primary database for session and participant data
- **Prometheus**: Metrics collection from PromEx
- **Grafana**: Visualization and dashboards

### Backend Deployment
- **Elixir Phoenix**: Single application handling REST API and WebSocket Channels with BEAM process coordination

## Directory Structure

```
k8s/
├── infrastructure/          # Infrastructure components
│   ├── namespace.yaml      # Namespaces for organization
│   └── postgresql.yaml     # PostgreSQL database
├── elixir/                 # Elixir backend manifests
│   ├── deployment.yaml     # Phoenix application
│   └── hpa.yaml            # Horizontal Pod Autoscaler
├── monitoring/             # Monitoring stack
│   ├── prometheus.yaml     # Prometheus configuration
│   └── grafana.yaml        # Grafana dashboards
├── deploy.sh               # Deployment automation script
└── README.md               # This file
```

## Deployment

```bash
# Deploy complete stack
./k8s/deploy.sh elixir deploy
```
Deploys:
- Infrastructure (PostgreSQL)
- Elixir Phoenix backend
- Monitoring stack (Prometheus + Grafana)

## Prerequisites

1. **Kubernetes Cluster**: Working Kubernetes cluster (local or cloud)
2. **kubectl**: Configured to access your cluster
3. **Docker Images**: Built and available to cluster
4. **Storage**: Persistent storage for databases

### Required Docker Images
```bash
# Build the Docker images first
docker build -t location-sharing/rust-backend:latest backend_rust/
docker build -t location-sharing/elixir-backend:latest backend_elixir/
```

## Configuration

### Environment Variables
All backends use ConfigMaps for environment-specific configuration:
- Database credentials
- Redis connection strings
- JWT secrets
- Application settings

### Resource Limits
Each service has defined resource requests and limits:
- **Rust API**: 128Mi-512Mi memory, 100m-500m CPU
- **Rust WebSocket**: 128Mi-512Mi memory, 100m-500m CPU
- **Elixir Backend**: 256Mi-1Gi memory, 150m-750m CPU
- **PostgreSQL**: 256Mi-1Gi memory, 250m-500m CPU
- **Redis**: 256Mi-2Gi memory, 250m-500m CPU

## Auto-scaling Configuration

### Horizontal Pod Autoscaler (HPA)
Both backends include HPA configurations:

**Rust Backend**:
- API Server: 3-20 replicas
- WebSocket Server: 2-15 replicas
- Scale up: 100% increase every 15s
- Scale down: 50% decrease every 60s

**Elixir Backend**:
- Application: 3-25 replicas
- Scale up: 100% increase every 15s
- Scale down: 50% decrease every 60s

### Scaling Triggers
- **CPU**: Target 70% utilization
- **Memory**: Target 80% utilization
- **Custom Metrics**: WebSocket connections, request rate (if configured)

## Monitoring

### Prometheus Metrics
Automated scraping of:
- Application metrics (HTTP requests, WebSocket connections)
- System metrics (CPU, memory, network)
- Database metrics (connections, query performance)
- Redis metrics (connections, memory, pub/sub)

### Grafana Dashboards
Pre-configured dashboards for:
- Backend performance comparison
- Resource utilization
- Error rates and response times
- WebSocket connection monitoring

### Alerting Rules
Built-in alerts for:
- High error rates (>10%)
- High response times (>500ms P95)
- Resource exhaustion (>90% memory, >80% CPU)
- Connection limits (WebSocket, Redis, Database)

## Accessing Services

### Port Forwarding
```bash
# Rust API
kubectl port-forward svc/rust-api 8000:8000 -n location-sharing

# Elixir Backend
kubectl port-forward svc/elixir-backend 4000:4000 -n location-sharing

# Prometheus
kubectl port-forward svc/prometheus 9090:9090 -n location-sharing-monitoring

# Grafana
kubectl port-forward svc/grafana 3000:3000 -n location-sharing-monitoring
```

### Load Balancer (Cloud)
For cloud deployments, change service types to `LoadBalancer`:
```yaml
spec:
  type: LoadBalancer
```

## Troubleshooting

### Common Issues

1. **Image Pull Errors**
   ```bash
   # Check if images are available
   docker images | grep location-sharing
   
   # If using local images, ensure they're loaded into cluster
   # For minikube: eval $(minikube docker-env)
   ```

2. **Database Connection Issues**
   ```bash
   # Check PostgreSQL pod status
   kubectl get pods -l app=postgres -n location-sharing
   
   # Check logs
   kubectl logs -l app=postgres -n location-sharing
   ```

3. **Service Discovery Issues**
   ```bash
   # Check DNS resolution
   kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup postgres.location-sharing.svc.cluster.local
   ```

### Useful Commands

```bash
# Check all resources
kubectl get all -n location-sharing

# View resource usage
kubectl top pods -n location-sharing

# Scale manually
kubectl scale deployment/rust-api --replicas=5 -n location-sharing

# View HPA status
kubectl get hpa -n location-sharing

# Debug pod issues
kubectl describe pod <pod-name> -n location-sharing

# View logs
kubectl logs -f deployment/rust-api -n location-sharing
```

## Performance Testing

After deployment, run stress tests against the Kubernetes services:

```bash
# Update test URLs to use port-forwarded services
export API_URL="http://localhost:8000"  # Rust
export API_URL="http://localhost:4000"  # Elixir

# Run stress tests
./stress-tests/run-tests.sh rust load_test api
./stress-tests/run-tests.sh elixir load_test api
```

## Production Considerations

### Security
- Use Kubernetes secrets for sensitive data
- Configure network policies
- Enable RBAC and pod security policies
- Use private Docker registries

### High Availability
- Deploy across multiple nodes/zones
- Configure pod disruption budgets
- Use StatefulSets for stateful services
- Implement backup strategies

### Scaling Strategy
- Monitor application-specific metrics
- Configure custom metrics for HPA
- Use cluster autoscaler for node scaling
- Implement circuit breakers

### Resource Management
- Set resource quotas per namespace
- Use limit ranges for pods
- Monitor resource usage trends
- Plan capacity based on growth

## Clean Up

```bash
# Delete specific backend
./k8s/deploy.sh rust delete

# Delete everything
./k8s/deploy.sh both delete

# Manual cleanup if needed
kubectl delete namespace location-sharing
kubectl delete namespace location-sharing-monitoring
```