#!/bin/bash

# Kubernetes Deployment Script for Location Sharing Backends
# This script deploys both backends and monitoring stack to Kubernetes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

BACKEND=${1:-both}
MODE=${2:-deploy}

echo -e "${PURPLE}============================================${NC}"
echo -e "${PURPLE}    Kubernetes Deployment Script           ${NC}"
echo -e "${PURPLE}============================================${NC}"
echo ""

# Validate inputs
if [[ ! "$BACKEND" =~ ^(rust|elixir|both)$ ]]; then
    echo -e "${RED}Error: Invalid backend '$BACKEND'${NC}"
    echo -e "Valid options: rust, elixir, both"
    exit 1
fi

if [[ ! "$MODE" =~ ^(deploy|delete|status)$ ]]; then
    echo -e "${RED}Error: Invalid mode '$MODE'${NC}"
    echo -e "Valid options: deploy, delete, status"
    exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl is not installed or not in PATH${NC}"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Cannot access Kubernetes cluster${NC}"
    echo -e "Please ensure kubectl is configured and cluster is accessible"
    exit 1
fi

echo -e "${GREEN}✓ Kubernetes cluster is accessible${NC}"
echo -e "${BLUE}Cluster Info:${NC}"
kubectl cluster-info | head -3

# Functions
deploy_infrastructure() {
    echo -e "${YELLOW}Deploying infrastructure...${NC}"
    
    # Create namespaces
    kubectl apply -f k8s/infrastructure/namespace.yaml
    
    # Deploy PostgreSQL
    echo -e "${BLUE}Deploying PostgreSQL...${NC}"
    kubectl apply -f k8s/infrastructure/postgresql.yaml
    
    # Deploy Redis
    echo -e "${BLUE}Deploying Redis...${NC}"
    kubectl apply -f k8s/infrastructure/redis.yaml
    
    # Wait for infrastructure to be ready
    echo -e "${YELLOW}Waiting for infrastructure to be ready...${NC}"
    kubectl wait --for=condition=ready pod -l app=postgres -n location-sharing --timeout=300s
    kubectl wait --for=condition=ready pod -l app=redis -n location-sharing --timeout=300s
    
    echo -e "${GREEN}✓ Infrastructure deployed successfully${NC}"
}

deploy_rust_backend() {
    echo -e "${YELLOW}Deploying Rust backend...${NC}"
    
    # Build Docker images (assuming they exist)
    echo -e "${BLUE}Note: Ensure Rust Docker images are built and available${NC}"
    
    # Deploy Rust services
    kubectl apply -f k8s/rust/deployment.yaml
    kubectl apply -f k8s/rust/hpa.yaml
    
    # Wait for deployments
    echo -e "${YELLOW}Waiting for Rust services to be ready...${NC}"
    kubectl wait --for=condition=available deployment/rust-api -n location-sharing --timeout=300s
    kubectl wait --for=condition=available deployment/rust-websocket -n location-sharing --timeout=300s
    
    echo -e "${GREEN}✓ Rust backend deployed successfully${NC}"
}

deploy_elixir_backend() {
    echo -e "${YELLOW}Deploying Elixir backend...${NC}"
    
    # Build Docker images (assuming they exist)
    echo -e "${BLUE}Note: Ensure Elixir Docker images are built and available${NC}"
    
    # Deploy Elixir services
    kubectl apply -f k8s/elixir/deployment.yaml
    kubectl apply -f k8s/elixir/hpa.yaml
    
    # Wait for deployments
    echo -e "${YELLOW}Waiting for Elixir services to be ready...${NC}"
    kubectl wait --for=condition=available deployment/elixir-backend -n location-sharing --timeout=300s
    
    echo -e "${GREEN}✓ Elixir backend deployed successfully${NC}"
}

deploy_monitoring() {
    echo -e "${YELLOW}Deploying monitoring stack...${NC}"
    
    # Deploy Prometheus
    kubectl apply -f k8s/monitoring/prometheus.yaml
    
    # Deploy Grafana
    kubectl apply -f k8s/monitoring/grafana.yaml
    
    # Wait for monitoring stack
    echo -e "${YELLOW}Waiting for monitoring stack to be ready...${NC}"
    kubectl wait --for=condition=available deployment/prometheus -n location-sharing-monitoring --timeout=300s
    kubectl wait --for=condition=available deployment/grafana -n location-sharing-monitoring --timeout=300s
    
    echo -e "${GREEN}✓ Monitoring stack deployed successfully${NC}"
}

delete_resources() {
    echo -e "${YELLOW}Deleting resources...${NC}"
    
    if [[ "$BACKEND" == "rust" || "$BACKEND" == "both" ]]; then
        echo -e "${BLUE}Deleting Rust backend...${NC}"
        kubectl delete -f k8s/rust/hpa.yaml --ignore-not-found=true
        kubectl delete -f k8s/rust/deployment.yaml --ignore-not-found=true
    fi
    
    if [[ "$BACKEND" == "elixir" || "$BACKEND" == "both" ]]; then
        echo -e "${BLUE}Deleting Elixir backend...${NC}"
        kubectl delete -f k8s/elixir/hpa.yaml --ignore-not-found=true
        kubectl delete -f k8s/elixir/deployment.yaml --ignore-not-found=true
    fi
    
    if [[ "$BACKEND" == "both" ]]; then
        echo -e "${BLUE}Deleting monitoring stack...${NC}"
        kubectl delete -f k8s/monitoring/grafana.yaml --ignore-not-found=true
        kubectl delete -f k8s/monitoring/prometheus.yaml --ignore-not-found=true
        
        echo -e "${BLUE}Deleting infrastructure...${NC}"
        kubectl delete -f k8s/infrastructure/redis.yaml --ignore-not-found=true
        kubectl delete -f k8s/infrastructure/postgresql.yaml --ignore-not-found=true
        kubectl delete -f k8s/infrastructure/namespace.yaml --ignore-not-found=true
    fi
    
    echo -e "${GREEN}✓ Resources deleted successfully${NC}"
}

show_status() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}    Current Deployment Status              ${NC}"
    echo -e "${BLUE}============================================${NC}"
    
    echo -e "${YELLOW}Namespaces:${NC}"
    kubectl get namespaces | grep -E "(location-sharing|NAME)"
    
    echo -e "${YELLOW}Infrastructure (location-sharing):${NC}"
    kubectl get pods,svc -n location-sharing
    
    echo -e "${YELLOW}Monitoring (location-sharing-monitoring):${NC}"
    kubectl get pods,svc -n location-sharing-monitoring
    
    echo -e "${YELLOW}Horizontal Pod Autoscalers:${NC}"
    kubectl get hpa -n location-sharing
    
    echo -e "${YELLOW}Persistent Volume Claims:${NC}"
    kubectl get pvc -n location-sharing
    kubectl get pvc -n location-sharing-monitoring
}

# Main execution
case "$MODE" in
    "deploy")
        if [[ "$BACKEND" == "both" ]]; then
            deploy_infrastructure
            deploy_rust_backend
            deploy_elixir_backend
            deploy_monitoring
        elif [[ "$BACKEND" == "rust" ]]; then
            deploy_infrastructure
            deploy_rust_backend
        elif [[ "$BACKEND" == "elixir" ]]; then
            deploy_infrastructure
            deploy_elixir_backend
        fi
        
        echo -e "${GREEN}============================================${NC}"
        echo -e "${GREEN}    Deployment Complete!                  ${NC}"
        echo -e "${GREEN}============================================${NC}"
        echo ""
        echo -e "${BLUE}Access Information:${NC}"
        echo -e "  Port forward to access services:"
        echo -e "  ${YELLOW}kubectl port-forward svc/rust-api 8000:8000 -n location-sharing${NC}"
        echo -e "  ${YELLOW}kubectl port-forward svc/elixir-backend 4000:4000 -n location-sharing${NC}"
        echo -e "  ${YELLOW}kubectl port-forward svc/prometheus 9090:9090 -n location-sharing-monitoring${NC}"
        echo -e "  ${YELLOW}kubectl port-forward svc/grafana 3000:3000 -n location-sharing-monitoring${NC}"
        echo ""
        echo -e "${BLUE}Monitoring:${NC}"
        echo -e "  Prometheus: http://localhost:9090"
        echo -e "  Grafana: http://localhost:3000 (admin/admin123)"
        ;;
    
    "delete")
        delete_resources
        ;;
    
    "status")
        show_status
        ;;
esac

echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo -e "  Show status: ${YELLOW}./k8s/deploy.sh both status${NC}"
echo -e "  Delete all: ${YELLOW}./k8s/deploy.sh both delete${NC}"
echo -e "  Logs: ${YELLOW}kubectl logs -f deployment/rust-api -n location-sharing${NC}"
echo -e "  Scale: ${YELLOW}kubectl scale deployment/rust-api --replicas=5 -n location-sharing${NC}"