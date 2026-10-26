# oidc.tf
# 「GitHub Actions が発行するトークンを AWS が信頼する」ための設定。
#
# 全体像:
#   1. OIDC プロバイダ    … 「GitHub（token.actions.githubusercontent.com）が発行したトークンを信頼する」と AWS に登録する
#   2. IAM ロール          … GitHub Actions が一時的に「なりすます」AWS 上の役割
#   3. 信頼ポリシー        … 「誰が」このロールを引き受けられるか（= どのリポジトリ・ブランチのワークフローか）
#   4. 権限ポリシー        … ロールを引き受けた後に「何が」できるか（= ECR への push だけ）

locals {
  github_oidc_url = "https://token.actions.githubusercontent.com"
}

# ------------------------------------------------------------
# 1. OIDC プロバイダ
# ------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  # count = 1 なら作成、0 なら作成しない（create_oidc_provider 変数で切り替え）
  count = var.create_oidc_provider ? 1 : 0

  # トークンの発行者（issuer）。トークン内の "iss" がこの URL と一致するものだけを受け付ける
  url = local.github_oidc_url

  # トークンの宛先（audience）。トークン内の "aud" がこの値のものだけを受け付ける。
  # aws-actions/configure-aws-credentials はデフォルトで "sts.amazonaws.com" を宛先にしてトークンを要求する
  client_id_list = ["sts.amazonaws.com"]

  # thumbprint_list（証明書の指紋）は省略している。
  # GitHub の OIDC については AWS が信頼済みの認証局で検証するため、現在は指定不要。
}

# create_oidc_provider = false のときは、アカウントに既にあるプロバイダを参照する
data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = local.github_oidc_url
}

locals {
  # 新規作成した場合と既存を参照した場合のどちらでも、ARN をここから取れるようにする
  github_oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

# ------------------------------------------------------------
# 2 + 3. IAM ロールと信頼ポリシー
# ------------------------------------------------------------

# 信頼ポリシー（ロールを「誰が」引き受けられるか）
# aws_iam_policy_document は、HCL で書いた内容を IAM ポリシーの JSON に変換してくれるデータソース
data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    sid    = "AllowGitHubActionsOIDC"
    effect = "Allow"

    # 許可する操作: Web ID（OIDC トークン）を使ってロールを引き受ける
    actions = ["sts:AssumeRoleWithWebIdentity"]

    # 誰からのリクエストか: 上で登録した GitHub の OIDC プロバイダが発行したトークンを持つ者
    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    # トークンの宛先（aud）が STS であること
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # トークンの主体（sub）が「指定リポジトリの指定ブランチ」であること。
    # これが無いと、GitHub 上の「どのリポジトリのワークフローでも」このロールを引き受けられてしまう。
    # 例: repo:hasekazu/study-cicd:ref:refs/heads/main
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:ref:refs/heads/${var.github_branch}"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions"
  # AWS の description に使える文字は ASCII と一部の欧文記号だけ（日本語は不可）なので英語で書く
  description        = "Assumed by GitHub Actions (${var.github_repository}) via OIDC to push images to ECR"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json

  # 1 回の引き受けで得られる一時認証情報の有効期間（秒）。1 時間（最小値）
  max_session_duration = 3600
}

# ------------------------------------------------------------
# 4. 権限ポリシー（ロールを引き受けた後に何ができるか）
# ------------------------------------------------------------
data "aws_iam_policy_document" "ecr_push" {
  # ECR へのログイン用トークン取得。この操作は特定のリポジトリに紐づかないため、Resource は "*" しか指定できない
  statement {
    sid       = "GetAuthorizationToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # イメージの push に必要な操作。対象はこのプロジェクトの ECR リポジトリ 1 つだけに限定する
  statement {
    sid    = "PushToRepository"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability", # レイヤーが既に存在するか確認（存在すればアップロードを省略）
      "ecr:InitiateLayerUpload",         # レイヤーのアップロード開始
      "ecr:UploadLayerPart",             # レイヤーのデータ送信
      "ecr:CompleteLayerUpload",         # レイヤーのアップロード完了
      "ecr:PutImage",                    # イメージ（マニフェスト）にタグを付けて登録
      "ecr:BatchGetImage",               # 既存イメージのマニフェスト取得（push 時に docker が参照することがある）
    ]
    resources = [aws_ecr_repository.app.arn]
  }
}

resource "aws_iam_role_policy" "ecr_push" {
  name   = "ecr-push"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.ecr_push.json
}
