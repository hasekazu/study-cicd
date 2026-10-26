# ecs.tf
# ECS（Elastic Container Service）でコンテナを動かす設定。
#
# 用語:
#   クラスター       … タスクをまとめる入れ物（クラスター自体は無料）
#   タスク定義       … 「どのイメージを、どの CPU・メモリで、どんな設定で動かすか」の設計図
#   タスク           … タスク定義から起動された、実際に動いているコンテナ（料金はこれにかかる）
#   サービス         … 「タスクを常に N 個動かし続ける」管理役。落ちたら自動で起動し直し、ALB に登録する
#   Fargate          … サーバー（EC2）を自分で用意せずにコンテナを動かせる実行環境

# 既存の ECR リポジトリ（../terraform で作成）を参照する。ここでは作成も削除もしない
data "aws_ecr_repository" "app" {
  name = var.ecr_repository_name
}

# ------------------------------------------------------------
# CloudWatch Logs
# ------------------------------------------------------------
# コンテナの標準出力（Spring Boot のログ）の保存先。
# Terraform で作るので、terraform destroy でロググループごと削除される
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = var.log_retention_days
}

# ------------------------------------------------------------
# タスク実行ロール
# ------------------------------------------------------------
# ECS（の Fargate エージェント）がタスクを起動するときに使う権限。
# アプリ自身の権限ではなく、「ECR からイメージを取得する」「CloudWatch Logs にログを書く」ためのもの
data "aws_iam_policy_document" "ecs_tasks_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    # ECS のタスクだけがこのロールを引き受けられる
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_execution" {
  name               = "${var.project_name}-ecs-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
}

# AWS が用意している管理ポリシー。ECR からの取得と CloudWatch Logs への書き込みの権限が含まれる
resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ------------------------------------------------------------
# クラスター
# ------------------------------------------------------------
resource "aws_ecs_cluster" "main" {
  name = var.project_name

  # Container Insights（詳細なメトリクス収集）は追加料金がかかるので無効にする
  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

# このクラスターで使える起動方法（キャパシティプロバイダー）として、通常の Fargate と Fargate Spot を登録する
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
}

# ------------------------------------------------------------
# タスク定義
# ------------------------------------------------------------
resource "aws_ecs_task_definition" "app" {
  family = var.project_name

  # Fargate で動かす。ネットワークモードは awsvpc（タスクごとに専用のネットワークインターフェースと IP を持つ）が必須
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn

  # イメージは GitHub Actions（ubuntu-latest）でビルドしているので x86_64（amd64）
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  # コンテナの定義（JSON）。jsonencode で HCL から JSON に変換する
  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${data.aws_ecr_repository.app.repository_url}:${var.image_tag}"
      essential = true # このコンテナが止まったらタスク全体を止める

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        # JVM のヒープ（Java のオブジェクト置き場）の上限を、コンテナのメモリの 50% にする。
        # 残りはヒープ以外（クラスの情報、スレッドなど）が使う。512 MB で約 310 MB の使用を確認済み
        { name = "JAVA_TOOL_OPTIONS", value = "-XX:MaxRAMPercentage=50.0" }
      ]

      # ログの出力先: awslogs ドライバーで、標準出力を CloudWatch Logs に送る
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "app" # ログストリーム名: app/app/<タスクID>
        }
      }
    }
  ])
}

# ------------------------------------------------------------
# サービス
# ------------------------------------------------------------
resource "aws_ecs_service" "app" {
  name            = var.project_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn

  # 常に動かしておくタスクの数
  desired_count = 1

  # Fargate Spot か通常の Fargate かを選ぶ（use_fargate_spot 変数で切り替え）
  capacity_provider_strategy {
    capacity_provider = var.use_fargate_spot ? "FARGATE_SPOT" : "FARGATE"
    weight            = 1
  }

  network_configuration {
    subnets         = aws_subnet.public[*].id
    security_groups = [aws_security_group.task.id]
    # パブリック IP を付ける。NAT Gateway が無いので、これが無いと ECR からイメージを取得できない
    assign_public_ip = true
  }

  # 起動したタスクを ALB のターゲットグループに自動で登録する
  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  # タスク起動から ALB のヘルスチェックを始めるまでの猶予（秒）。
  # 0.25 vCPU だと Spring Boot の起動に時間がかかるので、その間に「異常」と判定されて
  # 入れ替えが繰り返されないよう長めにする
  health_check_grace_period_seconds = 300

  # デプロイが失敗し続けたら自動で止めて、前のタスク定義に戻す
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # リスナーより先にサービスを作ると、ターゲットグループが ALB に紐づいておらずエラーになるため順序を指定する
  depends_on = [
    aws_lb_listener.http,
    aws_ecs_cluster_capacity_providers.main,
    aws_iam_role_policy_attachment.task_execution,
  ]
}
