# Dockerfile（マルチステージビルド）
# ステージ 1 で jar をビルドし、ステージ 2 では jar だけを軽い実行用イメージにコピーする。
# こうすると最終イメージにソースコードや Gradle、JDK（コンパイラ）が含まれず、小さく安全になる。

# ===== ステージ 1: ビルド用 =====
# JDK（コンパイラ入り）のイメージ。"AS build" で名前を付け、後のステージから参照できるようにする
FROM eclipse-temurin:21-jdk AS build
WORKDIR /workspace

# 先に Gradle の設定ファイルだけをコピーして依存ライブラリをダウンロードする。
# Docker はコマンドごとに結果をキャッシュするので、ソースだけを変更した場合は
# この重い手順がスキップされ、再ビルドが速くなる。
COPY gradlew settings.gradle build.gradle ./
COPY gradle ./gradle
RUN chmod +x gradlew && ./gradlew dependencies --no-daemon > /dev/null

# ソースをコピーして実行可能 jar を作る（テストは CI で実行するのでここでは省略）
COPY src ./src
RUN ./gradlew bootJar --no-daemon

# ===== ステージ 2: 実行用 =====
# JRE（実行に必要な部分だけ）のイメージなので JDK より小さい
FROM eclipse-temurin:21-jre
WORKDIR /app

# root 権限で動かさないよう、専用ユーザーを作って切り替える（セキュリティ対策）
RUN useradd --system --no-create-home appuser
USER appuser

# ステージ 1 で作った jar だけをコピーする
COPY --from=build /workspace/build/libs/*.jar app.jar

# このコンテナが 8080 番ポートを使うことを示す（ドキュメント的な意味。実際の公開は docker run -p で行う）
EXPOSE 8080

# コンテナ起動時に実行するコマンド
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
