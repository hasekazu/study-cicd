package com.example.studycicd.item;

import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

import org.springframework.stereotype.Repository;

/**
 * アイテムをメモリ上に保存するクラス（DB の代わり）。
 * アプリを再起動するとデータは消える。
 *
 * <p>{@code @Repository} を付けると、Spring がこのクラスのインスタンスを 1 つだけ作って管理する（Bean）。
 * 他のクラスはコンストラクタの引数に書くだけで、そのインスタンスを受け取れる（依存性注入 / DI）。
 */
@Repository
public class ItemRepository {

    // 複数のリクエストが同時に来ても壊れないよう、スレッドセーフな Map とカウンタを使う
    private final Map<Long, Item> items = new ConcurrentHashMap<>();
    private final AtomicLong sequence = new AtomicLong();

    /** id の昇順で全件を返す。 */
    public List<Item> findAll() {
        return items.values().stream()
                .sorted((a, b) -> Long.compare(a.id(), b.id()))
                .toList();
    }

    /** 新しい id を採番して保存し、保存したアイテムを返す。 */
    public Item save(String name, int price) {
        long id = sequence.incrementAndGet();
        Item item = new Item(id, name, price);
        items.put(id, item);
        return item;
    }

    /** 全件削除する（テストでデータを初期化するために使う）。 */
    public void deleteAll() {
        items.clear();
        sequence.set(0);
    }
}
