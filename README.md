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
├── .github/workflows/ci.yml   # GitHub Actions の CI 設定
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
