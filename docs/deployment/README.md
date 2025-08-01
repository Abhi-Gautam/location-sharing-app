# Deployment Guide

Complete guide for deploying the Location Sharing application to production environments.

## 🚀 Quick Deployment Options

### Option 1: Development/Testing (Local)
```bash
# Complete local setup
./run.sh --setup
./run.sh --start
```

### Option 2: Docker Compose (Recommended for Production)
```bash
# Production deployment with Docker
docker-compose -f docker-compose.prod.yml up -d
```

### Option 3: Kubernetes (Enterprise)
```bash
# Deploy to Kubernetes cluster
kubectl apply -f k8s/
```

## 🏗️ Architecture Overview

```
Production Deployment
├── Load Balancer (nginx/ALB)
├── Phoenix Backend (Multiple Instances)
├── PostgreSQL (Managed Service)
├── Static Assets (CDN)
└── Monitoring (Health Checks)
```

## 📋 Prerequisites

### Infrastructure Requirements
- **CPU**: 2+ cores per backend instance
- **Memory**: 1GB+ per backend instance  
- **Storage**: 20GB+ for database
- **Network**: HTTPS support, WebSocket compatibility

### External Services
- **Database**: PostgreSQL 13+ (managed service recommended)
- **SSL Certificate**: For HTTPS/WSS connections
- **Domain**: Custom domain for production access
- **Monitoring**: Health check endpoints

## 🐳 Docker Deployment

### 1. Production Docker Compose

Create `docker-compose.prod.yml`:
```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: location_sharing_prod
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    restart: unless-stopped

  backend:
    build: 
      context: ./backend_elixir
      dockerfile: Dockerfile.prod
    environment:
      MIX_ENV: prod
      DATABASE_URL: postgresql://${DB_USER}:${DB_PASSWORD}@postgres:5432/location_sharing_prod
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}
      JWT_SECRET: ${JWT_SECRET}
      PHX_HOST: ${DOMAIN}
      PORT: 4000
    ports:
      - "4000:4000"
    depends_on:
      - postgres
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  nginx:
    image: nginx:alpine
    ports:
      - "80:80" 
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - backend
    restart: unless-stopped

volumes:
  postgres_data:
```

### 2. Backend Dockerfile

Create `backend_elixir/Dockerfile.prod`:
```dockerfile
FROM elixir:1.15-alpine AS build

# Install build dependencies
RUN apk add --no-cache build-base git npm

# Set build environment
ENV MIX_ENV=prod

# Create app directory
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Install dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy source code
COPY . .

# Compile application
RUN mix compile

# Build release
RUN mix phx.gen.release
RUN mix release

# Start new stage for smaller image
FROM alpine:3.18

# Install runtime dependencies
RUN apk add --no-cache openssl ncurses-libs curl

# Create app user
RUN adduser -D -s /bin/sh app

# Set working directory
WORKDIR /home/app

# Copy release from build stage
COPY --from=build --chown=app:app /app/_build/prod/rel/location_sharing ./

# Switch to app user
USER app

# Expose port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:4000/health || exit 1

# Start application
CMD ["./bin/location_sharing", "start"]
```

### 3. Nginx Configuration

Create `nginx.conf`:
```nginx
events {
    worker_connections 1024;
}

http {
    upstream backend {
        server backend:4000;
    }

    # HTTP redirect to HTTPS
    server {
        listen 80;
        server_name your-domain.com;
        return 301 https://$server_name$request_uri;
    }

    # HTTPS configuration
    server {
        listen 443 ssl http2;
        server_name your-domain.com;

        # SSL configuration
        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;

        # API routes
        location /api/ {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Health check
        location /health {
            proxy_pass http://backend;
        }

        # WebSocket support
        location /socket/ {
            proxy_pass http://backend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_read_timeout 86400;
        }

        # Static files (if serving Flutter web)
        location / {
            root /var/www/html;
            try_files $uri $uri/ /index.html;
        }
    }
}
```

### 4. Environment Configuration

Create `.env.prod`:
```bash
# Database
DB_USER=location_sharing_user
DB_PASSWORD=secure_random_password
DATABASE_URL=postgresql://location_sharing_user:secure_random_password@postgres:5432/location_sharing_prod

# Security
SECRET_KEY_BASE=super_secure_64_character_random_string_for_phoenix_sessions
JWT_SECRET=another_secure_random_string_for_jwt_tokens

# Application
DOMAIN=your-domain.com
PORT=4000
MIX_ENV=prod

# Google Maps (for Flutter web)
GOOGLE_MAPS_API_KEY=your_google_maps_api_key
```

### 5. Deploy with Docker Compose
```bash
# Load environment variables
source .env.prod

# Build and start services
docker-compose -f docker-compose.prod.yml up -d

# Check status
docker-compose -f docker-compose.prod.yml ps

# View logs
docker-compose -f docker-compose.prod.yml logs -f backend

# Run database migrations
docker-compose -f docker-compose.prod.yml exec backend ./bin/location_sharing eval "LocationSharing.Release.migrate"
```

## ☸️ Kubernetes Deployment

### 1. Namespace and ConfigMap

`k8s/namespace.yml`:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: location-sharing
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: location-sharing
data:
  MIX_ENV: "prod"
  PHX_HOST: "your-domain.com"
  PORT: "4000"
```

### 2. Secrets

`k8s/secrets.yml`:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: location-sharing
type: Opaque
data:
  # Base64 encoded values
  database-url: <base64-encoded-database-url>
  secret-key-base: <base64-encoded-secret>
  jwt-secret: <base64-encoded-jwt-secret>
```

### 3. Backend Deployment

`k8s/backend-deployment.yml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: location-sharing
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: location-sharing-backend:latest
        ports:
        - containerPort: 4000
        env:
        - name: MIX_ENV
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: MIX_ENV
        - name: PHX_HOST
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: PHX_HOST
        - name: PORT
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: PORT
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: database-url
        - name: SECRET_KEY_BASE
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: secret-key-base
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: jwt-secret
        livenessProbe:
          httpGet:
            path: /health/live
            port: 4000
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 4000
          initialDelaySeconds: 5
          periodSeconds: 10
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: location-sharing
spec:
  selector:
    app: backend
  ports:
  - protocol: TCP
    port: 4000
    targetPort: 4000
```

### 4. Ingress Configuration

`k8s/ingress.yml`:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  namespace: location-sharing
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    nginx.ingress.kubernetes.io/websocket-services: backend-service
spec:
  tls:
  - hosts:
    - your-domain.com
    secretName: app-tls
  rules:
  - host: your-domain.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: backend-service
            port:
              number: 4000
      - path: /socket
        pathType: Prefix
        backend:
          service:
            name: backend-service
            port:
              number: 4000
      - path: /health
        pathType: Prefix
        backend:
          service:
            name: backend-service
            port:
              number: 4000
```

### 5. Deploy to Kubernetes
```bash
# Apply all configurations
kubectl apply -f k8s/

# Check deployment status
kubectl get pods -n location-sharing

# Check logs
kubectl logs -f deployment/backend -n location-sharing

# Run database migrations
kubectl exec -it deployment/backend -n location-sharing -- ./bin/location_sharing eval "LocationSharing.Release.migrate"
```

## 🏭 Production Considerations

### Database Management
```bash
# Automated backups
# Add to crontab:
0 2 * * * pg_dump location_sharing_prod | gzip > /backups/db_$(date +%Y%m%d).sql.gz

# Monitoring
# Add database monitoring for:
# - Connection pool usage
# - Query performance
# - Storage usage
```

### SSL/TLS Configuration
```bash
# Using Let's Encrypt with certbot
certbot --nginx -d your-domain.com

# Or integrate with cert-manager in Kubernetes
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.9.1/cert-manager.yaml
```

### Monitoring Setup
```yaml
# Prometheus monitoring (add to docker-compose.prod.yml)
prometheus:
  image: prom/prometheus
  ports:
    - "9090:9090"
  volumes:
    - ./prometheus.yml:/etc/prometheus/prometheus.yml

grafana:
  image: grafana/grafana
  ports:
    - "3000:3000"
  environment:
    - GF_SECURITY_ADMIN_PASSWORD=admin
```

### Scaling Configuration
```bash
# Horizontal Pod Autoscaler (Kubernetes)
kubectl autoscale deployment backend --cpu-percent=70 --min=3 --max=10 -n location-sharing

# Docker Compose scaling
docker-compose -f docker-compose.prod.yml up -d --scale backend=3
```

## 🔧 Release Process

### 1. Pre-deployment Checklist
- [ ] All tests passing (`./run.sh --test`)
- [ ] Environment variables configured
- [ ] SSL certificates ready
- [ ] Database backup completed
- [ ] Health check endpoints working
- [ ] WebSocket connectivity tested

### 2. Zero-downtime Deployment
```bash
# Using blue-green deployment
docker tag location-sharing-backend:latest location-sharing-backend:blue
docker-compose -f docker-compose.prod.yml up -d backend-green

# Test green deployment
curl https://your-domain.com/health

# Switch traffic to green
# Update load balancer configuration

# Remove blue deployment
docker-compose -f docker-compose.prod.yml stop backend-blue
```

### 3. Rollback Procedure
```bash
# Quick rollback to previous version
docker tag location-sharing-backend:previous location-sharing-backend:latest
docker-compose -f docker-compose.prod.yml up -d backend

# Database rollback (if needed)
pg_restore -d location_sharing_prod /backups/db_before_deployment.sql
```

## 📊 Monitoring & Health Checks

### Health Check Endpoints
- `GET /health` - Basic application health
- `GET /health/detailed` - Detailed dependency checks
- `GET /health/ready` - Kubernetes readiness probe
- `GET /health/live` - Kubernetes liveness probe

### Monitoring Setup
```yaml
# Prometheus configuration
global:
  scrape_interval: 15s

scrape_configs:
- job_name: 'location-sharing'
  static_configs:
  - targets: ['backend:4000']
  metrics_path: '/metrics'
```

### Alerts Configuration
- Database connection failures
- High response times (>1s)
- WebSocket connection drops
- Memory usage >80%
- Error rate >5%

## 🔒 Security Configuration

### SSL/TLS Best Practices
```nginx
# Strong SSL configuration
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
ssl_prefer_server_ciphers off;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 1d;
ssl_stapling on;
ssl_stapling_verify on;
```

### Security Headers
```nginx
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

### Firewall Configuration
```bash
# UFW example
ufw allow 22    # SSH
ufw allow 80    # HTTP
ufw allow 443   # HTTPS
ufw deny 4000   # Block direct backend access
ufw deny 5432   # Block direct database access
ufw enable
```

---

**Next Steps**: 
- Set up monitoring and alerting
- Configure automated backups
- Implement log aggregation
- Set up CI/CD pipeline
- Plan disaster recovery procedures