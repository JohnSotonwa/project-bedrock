output "app_bucket_name" {
  value = aws_s3_bucket.app_assets.id
}

output "vpc_id" {
  value = aws_vpc.project_vpc.id
}

output "cluster_name" {
  value = aws_eks_cluster.eks.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.eks.endpoint
}

output "region" {
  value = "us-east-1"
}

output "bedrock_dev_view_access_key_id" {
  value     = aws_iam_access_key.bedrock_dev_view_key.id
  sensitive = true
}

output "bedrock_dev_view_secret_access_key" {
  value     = aws_iam_access_key.bedrock_dev_view_key.secret
  sensitive = true
}

