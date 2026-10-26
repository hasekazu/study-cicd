# ecr.tf
# Docker イメージの保存先となる ECR（Elastic Container Registry）リポジトリ。

resource "aws_ecr_repository" "app" {
  name = var.project_name

  # MUTABLE: 同じタグを別のイメージに付け替えられる。
  # "latest" タグを毎回最新のイメージに付け替えるため MUTABLE にしている
  # （IMMUTABLE にすると 2 回目以降の latest の push が失敗する）。
  image_tag_mutability = "MUTABLE"

  # push 時に既知の脆弱性がないか自動でスキャンする（基本スキャンは無料）
  image_scanning_configuration {
    scan_on_push = true
  }

  # true: イメージが残っていても terraform destroy でリポジトリごと削除できる。
  # 学習用で後片付けを簡単にするため true にしている（本番では誤削除防止のため false が無難）
  force_delete = true
}

# ライフサイクルポリシー: 条件に合う古いイメージを ECR が自動で削除する（1 日 1 回程度の非同期実行）
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  # rulePriority の小さいルールから順に評価される
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 1 day" # タグが外れたイメージは 1 日後に削除
        # latest を新しいイメージに付け替えると、古いイメージから latest が外れる。
        # 他のタグ（コミットハッシュ）も無ければ untagged になり、このルールの対象になる
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only the latest ${var.ecr_keep_image_count} images" # 新しい順に N 個を残し、古いものを削除
        # tagStatus = "any" はすべてのイメージが対象。"any" のルールは最も大きい rulePriority にする必要がある。
        # 最新のイメージ（= latest が付いている）は常に残る
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.ecr_keep_image_count
        }
        action = { type = "expire" }
      },
    ]
  })
}
