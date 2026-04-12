terraform {
  required_version = ">= 1.5.0"
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

# 현재 AWS 계정 정보 가져오기
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}
