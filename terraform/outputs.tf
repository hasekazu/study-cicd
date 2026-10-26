# outputs.tf
# terraform apply の後に表示する値。`terraform output` でいつでも再表示できる。

output "github_actions_role_arn" {
  description = "GitHub Actions が引き受ける IAM ロールの ARN（GitHub のリポジトリ変数 AWS_ROLE_ARN に設定する）"
  value       = aws_iam_role.github_actions.arn
}

output "ecr_repository_url" {
  description = "ECR リポジトリの URL（docker push 先）"
  value       = aws_ecr_repository.app.repository_url
}
