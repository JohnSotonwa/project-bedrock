# ========================
# S3 bucket for app assets
# ========================
resource "aws_s3_bucket" "app_assets" {
  bucket = var.app_bucket_name
  tags = {
    Project = "barakat-2025-capstone"
  }
}

# ========================
# Private S3 Bucket
# ========================
resource "aws_s3_bucket_public_access_block" "assets_block" {
  bucket = aws_s3_bucket.app_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ========================
# VPC
# ========================
resource "aws_vpc" "project_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "project-bedrock-vpc"
    Project = "barakat-2025-capstone"
  }
}

# ========================
# Internet Gateway
# ========================
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.project_vpc.id

  tags = {
    Name    = "project-bedrock-igw"
    Project = "barakat-2025-capstone"
  }
}

# ========================
# Public subnets
# ========================
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.project_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name    = "project-bedrock-public-${count.index}"
    Project = "barakat-2025-capstone"
    "kubernetes.io/role/elb" = "1"
  }
}

# ========================
# Private Subnets
# ========================
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.project_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name    = "project-bedrock-private-${count.index}"
    Project = "barakat-2025-capstone"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# ====================================
# Public Route Table (Internet Access)
# ====================================
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.project_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name    = "project-bedrock-public-rt"
    Project = "barakat-2025-capstone"
  }
}

# ====================================
# Private Route Table (NAT)
# ====================================
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.project_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name    = "project-bedrock-private-rt"
    Project = "barakat-2025-capstone"
  }
}

# ================================================
# Public Route Table Association (Internet Access)
# ================================================
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# =================================================
# Private Route Table Association (NAT)
# =================================================
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ==============================
# Elastic IP
# ==============================
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Project = "barakat-2025-capstone"
  }
}

# ==============================
# NAT Gateway (In Public Subnet)
# ==============================
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name    = "project-bedrock-nat"
    Project = "barakat-2025-capstone"
  }
}

# ==============
# EKS cluster
# ==============
resource "aws_eks_cluster" "eks" {
  name     = var.eks_cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.34"

  vpc_config {
    subnet_ids = aws_subnet.public[*].id
  }

  tags = {
    Project = "barakat-2025-capstone"
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy]
}

# ======================
# EKS IAM role (Cluster)
# ======================
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role-bedrock"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Principal = { Service = "eks.amazonaws.com" },
        Effect    = "Allow"
      }
    ]
  })

  tags = {
    Project = "barakat-2025-capstone"
  }
}

# ========================
# IAM role Policy
# ========================
resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# ==============================
# EKS IAM role (For Worker Node)
# ==============================
resource "aws_iam_role" "eks_node_role" {
  name = "project-bedrock-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# ==============================
# Required Policies to Node Role
# ==============================
resource "aws_iam_role_policy_attachment" "node_worker_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ==============================
# Create EKS Node Group
# ==============================
resource "aws_eks_node_group" "bedrock_nodes" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "project-bedrock-node-group"
  node_role_arn  = aws_iam_role.eks_node_role.arn
  subnet_ids     = aws_subnet.private[*].id

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  capacity_type = "ON_DEMAND"

  tags = {
    Name = "project-bedrock-worker-node"
    Project = "barakat-2025-capstone"
  }
}

# ==============================
# IAM User  
# ==============================
resource "aws_iam_user" "bedrock_dev_view" {
  name = "bedrock-dev-view"

  tags = {
    Project = "barakat-2025-capstone"
  }
}

resource "aws_iam_user_policy_attachment" "readonly" {
  user       = aws_iam_user.bedrock_dev_view.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# ==============================
# IAM User Access Keys
# ==============================
resource "aws_iam_access_key" "bedrock_dev_view_key" {
  user = aws_iam_user.bedrock_dev_view.name
}

# =====================
# Add Cloudwatch IAM Role
# =====================
resource "aws_iam_role" "cloudwatch_role" {
  name = "project-bedrock-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = {
    Project = "barakat-2025-capstone"
  }
}

# ================================
# Add Cloudwatch IAM Role Policies
# ================================
resource "aws_iam_role_policy_attachment" "cloudwatch_attach" {
  role       = aws_iam_role.cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# =====================
# Add Cloudwatch
# =====================
resource "aws_eks_addon" "cloudwatch" {
  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "amazon-cloudwatch-observability"
  addon_version = "v4.10.0-eksbuild.1"   
  service_account_role_arn = aws_iam_role.cloudwatch_role.arn

  tags = {
    Project = "barakat-2025-capstone"
  }
}

# ==========================
# Create IAM role for Lambda
# ==========================
resource "aws_iam_role" "lambda_role" {
  name = "bedrock-asset-processor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role      = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ========================
# Lambda resource
# ========================
resource "aws_lambda_function" "asset_processor" {
  function_name = "bedrock-asset-processor"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.9"
  handler       = "index.lambda_handler"

  filename         = "lamda/lambda.zip"
  source_code_hash = filebase64sha256("lamda/lambda.zip")
}

# ========================
# Allow S3 to invoke Lambda
# ========================
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.asset_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.app_assets.arn
}

# ===========================
# Configure S3 → Lambda trigger
# ===========================
resource "aws_s3_bucket_notification" "asset_upload" {
  bucket = aws_s3_bucket.app_assets.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.asset_processor.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

