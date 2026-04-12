# terraform/iam.tf
# MongoDB VM에 부여할 IAM 역할 (의도적으로 과도한 권한 - EC2 생성 가능)
resource "aws_iam_role" "mongodb_vm" {
  name = "${var.project_name}-mongodb-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# 의도적으로 EC2 풀 접근 권한 부여 (면접 데모용 취약점)
resource "aws_iam_role_policy_attachment" "mongodb_ec2_full" {
  role       = aws_iam_role.mongodb_vm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

# S3 백업 접근 권한
resource "aws_iam_role_policy_attachment" "mongodb_s3" {
  role       = aws_iam_role.mongodb_vm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "mongodb_vm" {
  name = "${var.project_name}-mongodb-profile"
  role = aws_iam_role.mongodb_vm.name
}
