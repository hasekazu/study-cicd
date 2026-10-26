# study-cicd

Java 21 + Spring Boot で作った、CI/CD 学習用のシンプルな REST API です。
データはメモリ上に保存するため、アプリを再起動すると消えます。

## API

| メソッド | パス | 説明 |
|---|---|---|
| GET | `/items` | アイテム一覧を返す |
| POST | `/items` | アイテムを登録する（成功時 201、入力不正時 400） |
| GET | `/actuator/health` | ヘルスチェック（`{"status":"UP"}` を返す） |

## 必要なもの

- JDK 21
- Docker（コンテナで動かす場合のみ）

Gradle のインストールは不要です。同梱の Gradle Wrapper（`./gradlew`）が、必要なバージョンの Gradle を自動でダウンロードします。

## ローカルで起動する

```bash
./gradlew bootRun
```

起動したら別のターミナルで動作確認します。

```bash
# 登録
curl -X POST http://localhost:8080/items \
  -H 'Content-Type: application/json' \
  -d '{"name": "りんご", "price": 120}'
# => {"id":1,"name":"りんご","price":120}

# 一覧
curl http://localhost:8080/items
# => [{"id":1,"name":"りんご","price":120}]

# ヘルスチェック
curl http://localhost:8080/actuator/health
# => {"status":"UP","groups":["liveness","readiness"]}
```

停止するには `Ctrl + C` を押します。

### Docker で起動する

```bash
docker build -t study-cicd .
docker run --rm -p 8080:8080 study-cicd
```

## テストを実行する

```bash
./gradlew test
```

結果のレポートは `build/reports/tests/test/index.html` をブラウザで開くと確認できます。
`./gradlew build` を実行すると、コンパイル・テスト・jar の作成をまとめて行います（CI ではこれを実行しています）。

## ファイル構成と役割

```
.
├── .github/workflows/
│   ├── ci.yml                 # CI: ビルドとテスト
│   └── ecr-push.yml           # CI 成功後に Docker イメージを ECR に push
├── terraform/                 # AWS 側の設定（Terraform）
│   ├── versions.tf            #   Terraform・AWS プロバイダのバージョンとリージョン
│   ├── variables.tf           #   入力変数（リポジトリ名、ブランチ、残すイメージ数など）
│   ├── oidc.tf                #   OIDC プロバイダ、IAM ロール、信頼ポリシー、権限ポリシー
│   ├── ecr.tf                 #   ECR リポジトリとライフサイクルポリシー
│   ├── outputs.tf             #   apply 後に表示する値（ロール ARN、ECR の URL）
│   └── .terraform.lock.hcl    #   プロバイダのバージョン固定（コミットする）
├── gradle/wrapper/            # Gradle Wrapper の本体と設定（使う Gradle のバージョンを固定）
├── gradlew, gradlew.bat       # Gradle Wrapper の起動スクリプト（mac/Linux 用, Windows 用）
├── settings.gradle            # プロジェクト名の設定
├── build.gradle               # ビルド設定（プラグイン・依存ライブラリ・Java バージョン）
├── Dockerfile                 # コンテナイメージの作り方（マルチステージビルド）
├── .dockerignore              # docker build 時に除外するファイル
├── .gitignore                 # Git の管理から除外するファイル
└── src
    ├── main
    │   ├── java/com/example/studycicd
    │   │   ├── StudyCicdApplication.java   # 起動クラス（main メソッド）
    │   │   └── item
    │   │       ├── Item.java               # アイテムのデータ（id, name, price）
    │   │       ├── CreateItemRequest.java  # POST /items で受け取る入力と、その入力チェックのルール
    │   │       ├── ItemRepository.java     # アイテムをメモリに保存・取得する（DB の代わり）
    │   │       └── ItemController.java     # /items の HTTP リクエストを受け付ける
    │   └── resources
    │       └── application.yml             # アプリの設定（ポート番号、Actuator の公開範囲など）
    └── test/java/com/example/studycicd/item
        └── ItemControllerTest.java         # API のテスト（登録→一覧、入力エラー、ヘルスチェック）
```

各ファイルには、設定やアノテーションの意味を説明するコメントを書いてあります。

### 処理の流れ

```
HTTP リクエスト
  → ItemController（URL ごとに処理を振り分け、JSON ⇔ Java オブジェクトを変換）
  → ItemRepository（メモリ上の Map に保存・取得）
```

### CI（`.github/workflows/ci.yml`）

GitHub に push するか、プルリクエストを作成・更新すると自動で実行されます。

1. コードをチェックアウト
2. JDK 21 をセットアップし、Gradle の依存ライブラリのキャッシュを復元
3. `./gradlew build` でビルドとテストを実行
4. 失敗した場合はテストレポートをアーティファクトとして保存

結果は GitHub リポジトリの「Actions」タブで確認できます。

## ECR へのイメージ push（OIDC 認証）

`main` ブランチで CI が成功すると、`.github/workflows/ecr-push.yml` が Docker イメージをビルドし、Amazon ECR に push します。
AWS のアクセスキーは GitHub に一切保存せず、**OIDC** で IAM ロールを引き受けて、1 時間で失効する一時的な認証情報を使います。

イメージには次の 2 つのタグが付きます。

- `<コミットハッシュ>`(例: `3f2442e...`): どのコミットから作ったイメージかが分かる。変わらない
- `latest`: 常に最新のイメージを指す。push のたびに付け替わる

### セットアップ手順

前提: AWS CLI で、IAM と ECR を操作できる権限の認証情報が設定されていること(`aws sts get-caller-identity` で確認できます)。

```bash
# 1. AWS 側のリソースを作成する
cd terraform
terraform init        # プロバイダ(AWS 用プラグイン)をダウンロード
terraform plan        # 何が作られるかを確認(この時点では何も作られない)
terraform apply       # 内容を確認して yes を入力すると作成される

# 2. 作成した IAM ロールの ARN を、GitHub のリポジトリ変数 AWS_ROLE_ARN に設定する
gh variable set AWS_ROLE_ARN --body "$(terraform output -raw github_actions_role_arn)"
cd ..

# 3. main に push すると、CI → ECR push の順に実行される
git push
```

push されたイメージは次のコマンドで確認できます。

```bash
aws ecr describe-images --repository-name study-cicd --region ap-northeast-1 \
  --query 'imageDetails[].imageTags' --output table
```

> AWS アカウントに GitHub の OIDC プロバイダ(`token.actions.githubusercontent.com`)が既にある場合、`terraform apply` は「既に存在する」というエラーで失敗します(プロバイダは 1 アカウントに 1 つしか作れないため)。
> その場合は `terraform apply -var="create_oidc_provider=false"` を実行すると、既存のプロバイダを使います。

### 作成される AWS リソース

| リソース | 役割 |
|---|---|
| IAM OIDC プロバイダ | 「GitHub が発行したトークンを信頼する」という AWS アカウントへの登録 |
| IAM ロール `study-cicd-github-actions` | GitHub Actions が引き受けるロール |
| 信頼ポリシー(ロールに付属) | **誰が**ロールを引き受けられるか |
| 権限ポリシー `ecr-push` | ロールを引き受けた後に**何ができるか**(ECR リポジトリ 1 つへの push のみ) |
| ECR リポジトリ `study-cicd` | イメージの保存先 |
| ECR ライフサイクルポリシー | 古いイメージの自動削除 |

### OIDC 認証の仕組み

OIDC(OpenID Connect)は、「ある発行者が署名したトークンを見せれば、本人確認の代わりになる」仕組みです。
アクセスキーのような長期間有効な秘密情報を GitHub に保存する代わりに、**AWS が GitHub(トークンの発行者)を信頼する**ように設定します。

```
 GitHub Actions のジョブ               GitHub の OIDC 発行者                  AWS
 ─────────────────────               ────────────────────                 ───
 ① トークンを要求  ────────────────▶  ② 署名付きトークン(JWT)を発行
    (id-token: write が必要)           「repo:hasekazu/study-cicd:
                     ◀────────────────   ref:refs/heads/main のジョブです」
 ③ トークンを提示して
    ロール引き受けを要求  ──────────────────────────────────────────▶  ④ STS が検証
    (AssumeRoleWithWebIdentity)                                        ・署名は GitHub のものか
                                                                       ・信頼ポリシーの条件に合うか
                     ◀──────────────────────────────────────────────  ⑤ 一時認証情報を発行(1 時間)
 ⑥ 一時認証情報で ECR に push
```

1. ジョブが GitHub にトークンを要求します。ワークフローに `permissions: id-token: write` が無いと要求できません。
2. GitHub は、ジョブの情報(リポジトリ、ブランチ、イベントなど)を中身に含めたトークン(JWT)を発行し、GitHub の秘密鍵で署名します。
3. `aws-actions/configure-aws-credentials` が、このトークンを AWS STS に渡して IAM ロールの引き受けを要求します。
4. AWS STS は次を検証します。
   - **署名の検証**: トークンの発行者(`iss`)が、登録済みの OIDC プロバイダ(`token.actions.githubusercontent.com`)か。署名は GitHub が公開している公開鍵で検証するので、偽造したトークンは通りません。
   - **信頼ポリシーの検証**: トークンの中身(`aud`, `sub`)が、ロールの信頼ポリシーの条件に一致するか。
5. 検証に通ると、STS が 1 時間で失効する一時的な認証情報を発行します。
6. ジョブはその認証情報で ECR にログインし、push します。ここで何ができるかは**権限ポリシー**の範囲だけです。

つまり、信頼の連鎖は次のようになっています。

- AWS は **GitHub の署名** を信頼する(OIDC プロバイダの登録)
- IAM ロールは、**特定のリポジトリ・ブランチのジョブ** だけを信頼する(信頼ポリシー)
- そのロールには **ECR への push だけ** が許可されている(権限ポリシー)

万一ワークフローのログから認証情報が漏れても、1 時間で失効し、できることも ECR への push に限られます。

### 信頼ポリシーの各項目

`terraform/oidc.tf` の `github_actions_trust` から生成される信頼ポリシーは、次の JSON になります。

```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::<アカウントID>:oidc-provider/token.actions.githubusercontent.com"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
      "token.actions.githubusercontent.com:sub": "repo:hasekazu/study-cicd:ref:refs/heads/main"
    }
  }
}
```

| 項目 | 制御していること |
|---|---|
| `Effect: Allow` | 条件に合えば、ロールの引き受けを許可する |
| `Principal.Federated` | **どの発行者のトークンを受け付けるか**。登録した GitHub の OIDC プロバイダが発行したトークンだけを受け付ける。IAM ユーザーや他の AWS サービスからの引き受けはできない |
| `Action: sts:AssumeRoleWithWebIdentity` | **どの方法で引き受けられるか**。OIDC トークン(Web ID)を使った引き受けだけを許可する |
| `Condition` の `aud`(audience) | **トークンの宛先**。「AWS STS 宛て」に発行されたトークンだけを受け付ける。他のサービス向けに発行されたトークンを流用されるのを防ぐ |
| `Condition` の `sub`(subject) | **どのリポジトリ・ブランチのジョブか**。最も重要な条件。`hasekazu/study-cicd` の `main` ブランチで動くジョブだけを許可する |

**`sub` 条件の重要性**: GitHub の OIDC プロバイダは、GitHub 上の**すべてのリポジトリ**のトークンを同じ鍵で署名しています。
`sub` 条件が無いと、他人のリポジトリのワークフローからでもこのロールを引き受けられてしまいます。

`sub` の値はジョブのきっかけによって変わります。

| きっかけ | `sub` の例 | このロールを引き受けられるか |
|---|---|---|
| main への push(とその後の workflow_run) | `repo:hasekazu/study-cicd:ref:refs/heads/main` | できる |
| 別ブランチへの push | `repo:hasekazu/study-cicd:ref:refs/heads/feature-x` | できない |
| プルリクエスト | `repo:hasekazu/study-cicd:pull_request` | できない |
| 他のリポジトリ | `repo:someone/other-repo:...` | できない |

条件の演算子には `StringEquals`(完全一致)を使っています。`StringLike` を使うと、`repo:hasekazu/study-cicd:*` のようにワイルドカードで指定できます(全ブランチを許可する場合など)。範囲が広がるので、必要なときだけ使います。

### ECR ライフサイクルポリシー

ECR は、次のルールで古いイメージを自動削除します(1 日 1 回程度、非同期で実行されます)。

1. タグが 1 つも無い(untagged)イメージは、push から 1 日後に削除する
2. 新しい順に 10 個(`ecr_keep_image_count` で変更可)を残し、それより古いイメージを削除する。最新のイメージ(`latest` が付いている)は常に残る

### 削除手順(terraform destroy)

AWS のリソースを残すと、ECR のストレージ料金(少額)がかかり続けます。学習が終わったら削除してください。

```bash
cd terraform

# 1. 削除されるリソースを確認する(実際には削除されない)
terraform plan -destroy

# 2. 削除する(内容を確認して yes を入力)
terraform destroy

# 3. GitHub のリポジトリ変数も削除する
gh variable delete AWS_ROLE_ARN
```

- ECR リポジトリは `force_delete = true` にしているので、イメージが残っていてもリポジトリごと削除されます。
- `create_oidc_provider=false` で既存のプロバイダを使った場合、そのプロバイダは Terraform の管理外なので削除されません。
- 削除後に main へ push すると、`Push to ECR` ワークフローはロールが無いため失敗します。不要になったら、Actions タブでワークフローを無効化する(「…」→「Disable workflow」)か、`ecr-push.yml` を削除してください。
- `terraform.tfstate`(作ったリソースの記録)を消してしまうと、Terraform から削除できなくなります。destroy が終わるまでは消さないでください。
