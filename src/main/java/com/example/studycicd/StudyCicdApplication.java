package com.example.studycicd;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * アプリケーションの起動クラス（main メソッドがある場所）。
 *
 * <p>{@code @SpringBootApplication} は次の 3 つをまとめたアノテーション:
 * <ul>
 *   <li>{@code @Configuration}: このクラスを Spring の設定クラスとして扱う</li>
 *   <li>{@code @EnableAutoConfiguration}: 依存ライブラリを見て自動で設定する
 *       （例: spring-boot-starter-web があれば Tomcat を起動する）</li>
 *   <li>{@code @ComponentScan}: このパッケージ以下の {@code @RestController} や
 *       {@code @Repository} などを探して、Spring が管理するオブジェクト（Bean）として登録する</li>
 * </ul>
 * そのため、他のクラスはこのクラスと同じパッケージかその下に置く必要がある。
 */
@SpringBootApplication
public class StudyCicdApplication {

    public static void main(String[] args) {
        SpringApplication.run(StudyCicdApplication.class, args);
    }
}
