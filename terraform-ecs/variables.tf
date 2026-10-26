# variables.tf
# 入力変数。値は `terraform apply -var="name=value"` などで上書きできる。

variable "aws_region" {
  description = "リソースを作成する AWS リージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "リソース名の接頭辞やタグに使うプロジェクト名"
  type        = string
  default     = "study-cicd"
}

variable "ecr_repository_name" {
  description = "起動するイメージがある ECR リポジトリ名（../terraform で作成したもの）"
  type        = string
  default     = "study-cicd"
}

variable "image_tag" {
  description = "起動するイメージのタグ（コミットハッシュを指定すると、そのバージョンに固定できる）"
  type        = string
  default     = "latest"
}

variable "container_port" {
  description = "コンテナ内でアプリが待ち受けるポート（application.yml の server.port）"
  type        = number
  default     = 8080
}

# Fargate の CPU とメモリ。組み合わせは決まっていて、最小は 256 (0.25 vCPU) / 512 MB。
# 料金は CPU とメモリの量に比例するので、学習用には最小構成にする
variable "task_cpu" {
  description = "タスクの CPU ユニット（1024 = 1 vCPU）"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "タスクのメモリ（MB）"
  type        = number
  default     = 512
}

variable "use_fargate_spot" {
  description = <<-EOT
    true なら Fargate Spot（AWS の空き容量を使う割安な Fargate。通常より約 70% 安い）で動かす。
    AWS の都合で中断されることがあるが、ECS が自動で新しいタスクを起動し直す。
    学習用なのでコスト優先で true にしている。止まると困る用途では false にする。
  EOT
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch Logs にログを残す日数（保存量に応じて料金がかかるので短めにする）"
  type        = number
  default     = 1
}
