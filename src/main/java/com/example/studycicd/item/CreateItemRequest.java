package com.example.studycicd.item;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.PositiveOrZero;

/**
 * POST /items で受け取るリクエストボディ。
 *
 * <p>id はサーバー側で採番するので、クライアントからは name と price だけを受け取る。
 * フィールドに付けたアノテーションは入力チェックのルールで、Controller 側の
 * {@code @Valid} と組み合わせることで自動的にチェックされる。
 */
public record CreateItemRequest(
        // null・空文字・空白だけの文字列を禁止する
        @NotBlank String name,
        // 0 以上であること（マイナスの価格を禁止する）
        @PositiveOrZero int price) {
}
