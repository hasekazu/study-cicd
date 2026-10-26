# variables.tf
# 外から変更できる値（入力変数）の定義。
# 値は terraform.tfvars や、`terraform apply -var="..."` で上書きできる。

variable "aws_region" {
  description = "リソースを作成する AWS リージョン"
  type        = string
  default     = "ap-northeast-1" # 東京
}

variable "project_name" {
  description = "リソース名の接頭辞やタグに使うプロジェクト名"
  type        = string
  default     = "study-cicd"
}

variable "github_repository" {
  description = "AWS へのアクセスを許可する GitHub リポジトリ（owner/repo 形式）"
  type        = string
  default     = "hasekazu/study-cicd"
}

variable "github_branch" {
  description = "AWS へのアクセスを許可するブランチ。このブランチで動くワークフローだけがロールを引き受けられる"
  type        = string
  default     = "main"
}

variable "create_oidc_provider" {
  description = <<-EOT
    GitHub の OIDC プロバイダを新規作成するか。
    OIDC プロバイダは「AWS アカウントごとに URL 1 つにつき 1 つ」しか作れないため、
    すでに同じアカウントに token.actions.githubusercontent.com のプロバイダがある場合は false にする
    （その場合は既存のものを参照する）。
  EOT
  type        = bool
  default     = true
}

variable "ecr_keep_image_count" {
  description = "ECR に残すイメージの数。これより古いイメージはライフサイクルポリシーで自動削除される"
  type        = number
  default     = 10
}
