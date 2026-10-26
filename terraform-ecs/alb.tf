# alb.tf
# ALB（Application Load Balancer）: インターネットからの HTTP リクエストを受けて、Fargate タスクに転送する。
# 構成: ALB ─ リスナー（:80 で待ち受け）─ ターゲットグループ（転送先のタスクの集まり）

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  # false = インターネット向け（パブリックな DNS 名が付く）
  internal        = false
  subnets         = aws_subnet.public[*].id
  security_groups = [aws_security_group.alb.id]

  # true にすると terraform destroy で削除できなくなるので false（デフォルトも false）
  enable_deletion_protection = false
}

# ターゲットグループ: ALB の転送先と、その正常性の確認方法
resource "aws_lb_target_group" "app" {
  name     = "${var.project_name}-tg"
  port     = var.container_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  # Fargate のタスクは IP アドレスで登録される（EC2 インスタンス単位ではない）ため "ip" にする
  target_type = "ip"

  # タスクを外すとき、処理中のリクエストを待つ時間（デフォルト 300 秒）。
  # 学習用なので短くし、デプロイや destroy を速くする
  deregistration_delay = 10

  # ヘルスチェック: ALB が定期的にこの URL にアクセスし、200 が返るタスクにだけリクエストを転送する
  health_check {
    path                = "/actuator/health"
    matcher             = "200"
    interval            = 30 # 30 秒ごとに確認
    timeout             = 5
    healthy_threshold   = 2 # 2 回連続成功で「正常」
    unhealthy_threshold = 3 # 3 回連続失敗で「異常」（ECS がタスクを入れ替える）
  }
}

# リスナー: ALB が 80 番ポートで受けたリクエストを、すべてターゲットグループに転送する。
# HTTPS にするには独自ドメインと証明書（ACM）が必要なので、ここでは HTTP のみ
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
