# Infrastructure as Code Deployment Guide

## Overview

This notebook contains everything needed to deploy our application to production using modern DevOps practices.

## Prerequisites Check

```bash
# Check required tools
echo "Checking prerequisites..."

for tool in docker docker-compose kubectl terraform aws; do
  if command -v $tool &> /dev/null; then
    echo "✅ $tool is installed"
  else
    echo "❌ $tool is missing"
  fi
done

# Check versions
docker --version
kubectl version --client
terraform version
```

## Environment Configuration

```bash
# Set environment variables
export APP_NAME="kyozo"
export ENV="production"
export AWS_REGION="us-east-1"
export CLUSTER_NAME="kyozo-prod-cluster"

# Verify AWS credentials
aws sts get-caller-identity
```

## Build Docker Images

```dockerfile
# Dockerfile for Elixir application
FROM elixir:1.15-alpine AS build

# Install build dependencies
RUN apk add --no-cache build-base git python3

# Set build environment
ENV MIX_ENV=prod

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set working directory
WORKDIR /app

# Copy mix files
COPY mix.exs mix.lock ./
COPY config config

# Install dependencies
RUN mix deps.get --only $MIX_ENV
RUN mix deps.compile

# Copy application files
COPY priv priv
COPY lib lib
COPY assets assets

# Compile assets
RUN mix assets.deploy

# Build release
RUN mix release

# Start fresh for runtime
FROM alpine:3.18 AS runtime

RUN apk add --no-cache libstdc++ openssl ncurses-libs

WORKDIR /app

# Copy release from build stage
COPY --from=build /app/_build/prod/rel/kyozo ./

ENV HOME=/app

EXPOSE 4000

CMD ["bin/kyozo", "start"]
```

## Build and Push Images

```bash
# Build Docker image
docker build -t kyozo:latest .

# Tag for registry
docker tag kyozo:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/kyozo:latest

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Push to ECR
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/kyozo:latest
```

## Terraform Infrastructure

```hcl
# main.tf - Core infrastructure
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC Configuration
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "${var.app_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = true
  enable_dns_hostnames = true

  tags = {
    Environment = var.environment
    Application = var.app_name
  }
}

# EKS Cluster
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name    = var.cluster_name
  cluster_version = "1.27"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    main = {
      min_size     = 2
      max_size     = 10
      desired_size = 3

      instance_types = ["t3.medium"]
      
      tags = {
        Environment = var.environment
      }
    }
  }
}

# RDS Database
resource "aws_db_instance" "postgres" {
  identifier = "${var.app_name}-db"

  engine         = "postgres"
  engine_version = "15.3"
  instance_class = "db.t3.medium"

  allocated_storage     = 100
  max_allocated_storage = 500
  storage_encrypted     = true

  db_name  = var.app_name
  username = "postgres"
  password = random_password.db_password.result

  vpc_security_group_ids = [aws_security_group.db.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  backup_retention_period = 30
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  tags = {
    Environment = var.environment
  }
}
```

## Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var-file=production.tfvars

# Apply changes
terraform apply -var-file=production.tfvars -auto-approve

# Get EKS cluster config
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
```

## Kubernetes Manifests

```yaml
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: kyozo
---
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kyozo-app
  namespace: kyozo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: kyozo
  template:
    metadata:
      labels:
        app: kyozo
    spec:
      containers:
      - name: kyozo
        image: ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/kyozo:latest
        ports:
        - containerPort: 4000
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: kyozo-secrets
              key: database-url
        - name: SECRET_KEY_BASE
          valueFrom:
            secretKeyRef:
              name: kyozo-secrets
              key: secret-key-base
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 4000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 4000
          initialDelaySeconds: 5
          periodSeconds: 5
---
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: kyozo-service
  namespace: kyozo
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 4000
  selector:
    app: kyozo
---
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: kyozo-hpa
  namespace: kyozo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: kyozo-app
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

## Deploy to Kubernetes

```bash
# Create namespace
kubectl apply -f namespace.yaml

# Create secrets
kubectl create secret generic kyozo-secrets \
  --from-literal=database-url="postgresql://user:pass@host:5432/kyozo" \
  --from-literal=secret-key-base="$(openssl rand -hex 64)" \
  -n kyozo

# Deploy application
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f hpa.yaml

# Check deployment status
kubectl rollout status deployment/kyozo-app -n kyozo

# Get service endpoint
kubectl get service kyozo-service -n kyozo
```

## Setup Monitoring

```yaml
# prometheus-values.yaml
prometheus:
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    retention: 30d
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: gp3
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 100Gi

grafana:
  adminPassword: ${GRAFANA_ADMIN_PASSWORD}
  persistence:
    enabled: true
    storageClassName: gp3
    size: 10Gi
```

```bash
# Install Prometheus Operator
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  -f prometheus-values.yaml \
  -n monitoring \
  --create-namespace

# Port forward to access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

## Database Migrations

```bash
# Run migrations as Kubernetes Job
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migrate-$(date +%s)
  namespace: kyozo
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: migrate
        image: ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/kyozo:latest
        command: ["bin/kyozo", "eval", "Kyozo.Release.migrate"]
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: kyozo-secrets
              key: database-url
EOF

# Wait for migration to complete
kubectl wait --for=condition=complete job/db-migrate-* -n kyozo --timeout=300s
```

## Setup CI/CD Pipeline

```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-east-1

    - name: Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v1

    - name: Build and push Docker image
      env:
        ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
        IMAGE_TAG: ${{ github.sha }}
      run: |
        docker build -t $ECR_REGISTRY/kyozo:$IMAGE_TAG .
        docker push $ECR_REGISTRY/kyozo:$IMAGE_TAG
        docker tag $ECR_REGISTRY/kyozo:$IMAGE_TAG $ECR_REGISTRY/kyozo:latest
        docker push $ECR_REGISTRY/kyozo:latest

    - name: Update Kubernetes deployment
      run: |
        aws eks update-kubeconfig --name kyozo-prod-cluster --region us-east-1
        kubectl set image deployment/kyozo-app kyozo=$ECR_REGISTRY/kyozo:$IMAGE_TAG -n kyozo
        kubectl rollout status deployment/kyozo-app -n kyozo
```

## Verify Deployment

```bash
# Check pod status
kubectl get pods -n kyozo

# Check logs
kubectl logs -f deployment/kyozo-app -n kyozo

# Run health checks
curl -f http://$(kubectl get svc kyozo-service -n kyozo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')/health

# Check metrics
kubectl top pods -n kyozo
kubectl top nodes
```

## Rollback Procedure

```bash
# View deployment history
kubectl rollout history deployment/kyozo-app -n kyozo

# Rollback to previous version
kubectl rollout undo deployment/kyozo-app -n kyozo

# Rollback to specific revision
kubectl rollout undo deployment/kyozo-app --to-revision=2 -n kyozo
```

## Clean Up (if needed)

```bash
# Delete Kubernetes resources
kubectl delete namespace kyozo

# Destroy Terraform infrastructure
terraform destroy -var-file=production.tfvars -auto-approve
```