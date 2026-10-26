# versions.tf
# Terraform 本体と AWS プロバイダのバージョン、リージョンの設定。
#
# この terraform-ecs/ は、../terraform/（OIDC と ECR）とは別の Terraform プロジェクト。
# state（作ったリソースの記録）も別々なので、
# 費用のかかる ECS 側だけを destroy / apply でき、ECR とイメージはそのまま残せる。

terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      Component = "ecs"
      ManagedBy = "terraform"
    }
  }
}
