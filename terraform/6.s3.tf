# terraform/s3.tf
resource "aws_s3_bucket" "mongodb_backup" {
  bucket        = "${var.project_name}-mongodb-backup-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = { Name = "${var.project_name}-backup" }
}

# 퍼블릭 읽기 및 목록 허용 (의도적 - 면접 데모용)
resource "aws_s3_bucket_public_access_block" "mongodb_backup" {
  bucket                  = aws_s3_bucket.mongodb_backup.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "mongodb_backup" {
  bucket     = aws_s3_bucket.mongodb_backup.id
  depends_on = [aws_s3_bucket_public_access_block.mongodb_backup]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadGetObject"
      Effect    = "Allow"
      Principal = "*"
      Action    = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        "${aws_s3_bucket.mongodb_backup.arn}",
        "${aws_s3_bucket.mongodb_backup.arn}/*"
      ]
    }]
  })
}
