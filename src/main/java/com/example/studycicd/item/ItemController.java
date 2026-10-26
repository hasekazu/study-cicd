package com.example.studycicd.item;

import java.util.List;

import jakarta.validation.Valid;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * /items への HTTP リクエストを受け付けるクラス。
 *
 * <p>{@code @RestController}: このクラスを Web の窓口として登録する。
 * メソッドの戻り値は自動的に JSON に変換されてレスポンスになる。
 *
 * <p>{@code @RequestMapping("/items")}: このクラスのメソッドはすべて /items 配下の URL を担当する。
 */
@RestController
@RequestMapping("/items")
public class ItemController {

    private final ItemRepository repository;

    // コンストラクタが 1 つだけなら、Spring が自動で ItemRepository の Bean を渡してくれる（DI）
    public ItemController(ItemRepository repository) {
        this.repository = repository;
    }

    /** GET /items : 一覧を返す。 */
    @GetMapping
    public List<Item> list() {
        return repository.findAll();
    }

    /**
     * POST /items : アイテムを登録する。
     *
     * <ul>
     *   <li>{@code @RequestBody}: リクエストボディの JSON を CreateItemRequest に変換する</li>
     *   <li>{@code @Valid}: CreateItemRequest に付けた @NotBlank などのチェックを実行する。
     *       違反があると処理に入る前に 400 Bad Request が返る</li>
     *   <li>{@code @ResponseStatus(HttpStatus.CREATED)}: 成功時のステータスを 200 ではなく 201 Created にする</li>
     * </ul>
     */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Item create(@Valid @RequestBody CreateItemRequest request) {
        return repository.save(request.name(), request.price());
    }
}
