package com.example.studycicd.item;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

/**
 * API のテスト。
 *
 * <ul>
 *   <li>{@code @SpringBootTest}: 本番と同じようにアプリ全体（Controller, Repository, Actuator など）を起動してテストする</li>
 *   <li>{@code @AutoConfigureMockMvc}: 実際にポートを開かずに HTTP リクエストを疑似的に送れる
 *       MockMvc を使えるようにする</li>
 * </ul>
 */
@SpringBootTest
@AutoConfigureMockMvc
class ItemControllerTest {

    // @Autowired: Spring が管理しているオブジェクトをこのフィールドに注入してもらう
    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ItemRepository repository;

    // @BeforeEach: 各テストの前に毎回実行される。テスト同士がデータで影響し合わないよう初期化する
    @BeforeEach
    void setUp() {
        repository.deleteAll();
    }

    // @Test: このメソッドがテストであることを JUnit に伝える
    @Test
    void POSTで登録したアイテムがGETの一覧に含まれる() throws Exception {
        mockMvc.perform(post("/items")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name": "りんご", "price": 120}
                                """))
                .andExpect(status().isCreated())               // 201 Created
                .andExpect(jsonPath("$.id").value(1))          // 採番された id
                .andExpect(jsonPath("$.name").value("りんご"))
                .andExpect(jsonPath("$.price").value(120));

        mockMvc.perform(get("/items"))
                .andExpect(status().isOk())                    // 200 OK
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].name").value("りんご"));
    }

    @Test
    void nameが空なら400を返す() throws Exception {
        mockMvc.perform(post("/items")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name": "", "price": 100}
                                """))
                .andExpect(status().isBadRequest());           // 400 Bad Request
    }

    @Test
    void ヘルスチェックがUPを返す() throws Exception {
        mockMvc.perform(get("/actuator/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"));
    }
}
