# terraform/outputs.tf
output "eks_cluster_name" {
  value = aws_eks_cluster.main.name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "mongodb_public_ip" {
  value = aws_instance.mongodb.public_ip
}

output "s3_backup_bucket" {
  value = aws_s3_bucket.mongodb_backup.bucket
}
