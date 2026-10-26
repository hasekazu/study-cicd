# versions.tf
# Terraform 本体と、使うプロバイダ（AWS を操作するためのプラグイン）のバージョンを指定する。

terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # 6.x の範囲で最新を使う（7.0 のような互換性のない大きな更新は自動では入らない）
      version = "~> 6.0"
    }
  }

  # state（Terraform が作ったリソースの記録）は、このフォルダの terraform.tfstate に保存する。
  # 学習用なのでローカル保存にしている。チームで使う場合は S3 などのリモートに置くのが一般的。
}

provider "aws" {
  region = var.aws_region

  # このプロバイダで作るすべてのリソースに共通のタグを付ける（AWS コンソールでの判別用）
  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  }
}
