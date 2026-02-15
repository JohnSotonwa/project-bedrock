# Bedrock Retail App - Infrastructure as Code

This repository contains the Terraform, CI/CD pipeline, and Kubernetes manifests for deploying the Bedrock Retail Store project.

---

## Project Overview

Bedrock is a microservices-based retail application deployed on AWS using EKS. The infrastructure is provisioned via Terraform and managed through a CI/CD pipeline using GitHub Actions.

### Key Components

- **VPC:** `project-bedrock-vpc` with public and private subnets (2 AZs)
- **EKS Cluster:** `project-bedrock-cluster`
- **Node Group:** EC2 instances running microservices
- **Microservices:** carts, checkout, orders, catalog, ui
- **Observability:** Amazon CloudWatch for metrics and logging
- **Event-driven S3-Lambda flow:** `bedrock-assets-alt-soe-xxx` bucket triggers Lambda functions

---

## Repository Structure
```
.
├── backend.tf                    # Terraform remote state configuration (S3 + DynamoDB)
├── providers.tf                  # AWS provider configuration
├── main.tf                       # Core infrastructure resources
├── variables.tf                  # Input variables
├── outputs.tf                    # Terraform outputs
├── terraform.tfvars              # Environment-specific values
├── rbac-bedrock-dev-view.yaml    # Kubernetes RBAC configuration
├── aws/                          # Lambda functions or app assets
└── grading.json                  # Terraform output for grading
```

---

## Deployment Guide

### 1. Trigger the Pipeline
- Push changes to the `main` branch or create a pull request
- GitHub Actions will automatically run Terraform `plan` and `apply`

### 2. Access the Retail App
- Once deployed, the URL for the running application will be displayed in the Terraform outputs

### 3. Grading Credentials
Access Key & Secret Key for the `bedrock-dev-view` user:
- **Access Key:** Provided in `grading.json`
- **Secret Key:** Provided in `grading.json`

---

## Terraform Grading Output

Generate grading output for review:
```bash
terraform output -json > grading.json
```

**Note:** Ensure `grading.json` is committed to the repository root (without secrets in plain text if GitHub push protection is enabled).

---

## Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.0
- kubectl configured for EKS access
- GitHub repository with Actions enabled

---

## CI/CD Pipeline

The GitHub Actions workflow automatically:
1. Validates Terraform syntax
2. Plans infrastructure changes
3. Applies approved changes to AWS
4. Outputs deployment URLs and credentials

---

## Troubleshooting

### Common Issues

**EKS Node Group not ready:**
```bash
kubectl get nodes
# Wait for nodes to reach Ready state
```

**Terraform state lock:**
```bash
# Check DynamoDB for locks
aws dynamodb scan --table-name <lock-table-name>
```

**Application not accessible:**
```bash
# Check service endpoints
kubectl get svc -n <namespace>
```

---

## Security Considerations

- Secrets are managed via AWS Secrets Manager
- RBAC policies restrict access to `bedrock-dev-view` user
- S3 buckets use encryption at rest
- VPC security groups follow principle of least privilege

---
