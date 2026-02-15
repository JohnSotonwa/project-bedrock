variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "app_bucket_name" {
  type        = string
  description = "S3 bucket for storing app assets"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR block for the VPC"
}

variable "eks_cluster_name" {
  type        = string
  default     = "project-bedrock-cluster"
  description = "Name of the EKS cluster"
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
  description = "Availability zones for the VPC subnets"
}


#variable "lock_table_name" {
#  description = "DynamoDB table for Terraform state locking"
#  type        = string
#}

