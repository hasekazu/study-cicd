# outputs.tf
# terraform apply の後に表示する値。`terraform output` でいつでも再表示できる。

output "app_url" {
  description = "アプリの URL（ALB の DNS 名）"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecs_cluster_name" {
  description = "ECS クラスター名"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS サービス名"
  value       = aws_ecs_service.app.name
}

output "log_group_name" {
  description = "ログの保存先（CloudWatch Logs のロググループ）"
  value       = aws_cloudwatch_log_group.app.name
}
