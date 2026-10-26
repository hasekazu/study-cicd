# network.tf
# ネットワーク（VPC、サブネット、インターネットゲートウェイ、セキュリティグループ）。
#
# 構成:
#   インターネット
#     │ HTTP :80
#   [ALB]            … パブリックサブネット（2 つの AZ に配置。ALB は 2 AZ 以上が必須）
#     │ :8080（ALB からのみ許可）
#   [Fargate タスク]  … パブリックサブネット。パブリック IP を持つが、セキュリティグループで ALB 以外からの通信は拒否
#     │ HTTPS :443
#   ECR / CloudWatch Logs（インターネット経由で直接アクセス）
#
# コストのポイント:
#   通常はタスクをプライベートサブネットに置き、NAT Gateway（約 $45/月 + 通信料）や
#   VPC エンドポイント（1 つ約 $10/月 × 3〜4 個）経由で ECR にアクセスする。
#   ここではタスクをパブリックサブネットに置いてパブリック IP を持たせることで、それらを不要にしている
#   （パブリック IPv4 は 1 つ約 $3.6/月）。

# 利用可能な AZ（アベイラビリティゾーン）の一覧を取得する
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # 先頭の 2 つの AZ を使う（例: ap-northeast-1a, ap-northeast-1c）
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

# ------------------------------------------------------------
# VPC とサブネット
# ------------------------------------------------------------
resource "aws_vpc" "main" {
  # VPC 内で使う IP アドレスの範囲（10.0.0.0 〜 10.0.255.255）
  cidr_block = "10.0.0.0/16"

  # VPC 内で DNS 名前解決を使えるようにする（ECR などのホスト名を解決するのに必要）
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.project_name}-vpc" }
}

# インターネットゲートウェイ: VPC とインターネットをつなぐ出入口（無料）
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

# AZ ごとにパブリックサブネットを 1 つずつ作る（count で 2 つ作成）
resource "aws_subnet" "public" {
  count = length(local.azs)

  vpc_id            = aws_vpc.main.id
  availability_zone = local.azs[count.index]
  # 10.0.0.0/24, 10.0.1.0/24 のように VPC の範囲を分割する
  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)

  # このサブネットで起動したものに自動でパブリック IP を付けない（Fargate 側で明示的に付ける）
  map_public_ip_on_launch = false

  tags = { Name = "${var.project_name}-public-${local.azs[count.index]}" }
}

# ルートテーブル: 「宛先がどこなら、どこへ送るか」の表。
# 0.0.0.0/0（VPC 外のすべて）をインターネットゲートウェイへ送る = パブリックサブネットになる
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.project_name}-public-rt" }
}

# サブネットとルートテーブルを関連付ける
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------
# セキュリティグループ（ファイアウォール）
# ------------------------------------------------------------

# ALB 用: インターネットから HTTP(80) を受け付ける
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb"
  description = "ALB: allow HTTP from the internet"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from anywhere"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

# ALB からタスクへの転送（8080）だけを許可する
resource "aws_vpc_security_group_egress_rule" "alb_to_task" {
  security_group_id            = aws_security_group.alb.id
  description                  = "To ECS tasks"
  referenced_security_group_id = aws_security_group.task.id
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
}

# Fargate タスク用
resource "aws_security_group" "task" {
  name        = "${var.project_name}-task"
  description = "ECS task: allow traffic only from the ALB"
  vpc_id      = aws_vpc.main.id
}

# 受信: ALB のセキュリティグループからの 8080 だけを許可する。
# タスクはパブリック IP を持つが、これ以外の通信（インターネットから直接など）はすべて拒否される
resource "aws_vpc_security_group_ingress_rule" "task_from_alb" {
  security_group_id            = aws_security_group.task.id
  description                  = "From ALB"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
}

# 送信: HTTPS(443) を許可する。ECR からのイメージ取得と CloudWatch Logs へのログ送信に使う
resource "aws_vpc_security_group_egress_rule" "task_https" {
  security_group_id = aws_security_group.task.id
  description       = "HTTPS to ECR and CloudWatch Logs"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}
