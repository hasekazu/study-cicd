package com.example.studycicd.item;

/**
 * 1 件のアイテムを表すデータ。
 *
 * <p>{@code record} は Java 16 以降の機能で、フィールド・コンストラクタ・getter・
 * equals/hashCode/toString を自動生成してくれる「値を入れるだけのクラス」。
 * Spring（Jackson）はこれを自動で JSON {@code {"id":1,"name":"...","price":100}} に変換する。
 */
public record Item(long id, String name, int price) {
}
