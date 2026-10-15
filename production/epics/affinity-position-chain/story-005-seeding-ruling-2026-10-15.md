# story-005 追加裁決:開局關係資料暫代灌入(2026-10-15 管理者裁決)

> **本檔是新增的決策紀錄,不修改 story-005 原文一個字。**
> story-005 的 Acceptance Criteria 與 Implementation Notes 全部仍然有效;
> 本檔新增的是**一條原文沒有涵蓋、但照原文做完就會立刻發作的後果**的處理方式。

## 一、為什麼需要這次裁決(先講後果,再講機制)

story-005 把 `Φ` 的極性/強度來源,從靜態檔 `assets/data/affinity/vs01_affinity_links.txt`
改為向 `AffinityDataPool` 逐次查詢。**方向完全正確**(GDD `affinity-position-chain.md`
Interactions ① 明文裁決,靜態檔是暫代品)。

🔴 **但 `AffinityDataPool._init()` 把 10 對配對全部預填為「空的記錄串列」**
(`src/gameplay/affinity_pool/affinity_data_pool.gd` 的 `_init()`,見 `_records` 欄位
文件註解),亦即**開局每一對的 `n_pair` 都是 0**。而本專案目前**沒有任何東西**會在戰鬥
開場把「甲乙本來就要好」寫進池子:劇情卡牌寫入與讀存檔都還沒實作,存檔系統(ADR-0004)
依一年計畫第七節明文不在 12 個月範圍內。

**照 story-005 原文做完的實際畫面**:棋盤開局一條關係線都不畫、全體 `Φ` 恆 0,
而且在劇情卡牌 epic 排程之前都不會回來。

**實測證據(不是推論)** —— 未灌入版本跑全套時,這條既有接線測試由綠轉紅,
原始輸出逐字:

```
res://tests/integration/ui/battle/battle_screen_card_deck_wiring_test.gd > test_battle_controller_new_call_site_passes_card_deck_affinity_links_and_write_port FAILED 115ms
Report:
Expecting:
 0
 but was
 2	at 'test_battle_controller_new_call_site_passes_card_deck_affinity_links_and_write_port' in res://tests/integration/ui/battle/battle_screen_card_deck_wiring_test.gd:267  Expecting: 'true' but is 'false'	at 'test_battle_controller_new_call_site_passes_card_deck_affinity_links_and_write_port' in res://tests/integration/ui/battle/battle_screen_card_deck_wiring_test.gd:268
```

該測試第 268 行斷言的是 `instance._phi.links().size() > 0`。**它量到 0。**
同一次量測中,`BattleController` 從靜態檔拿到的那份 `_links` 仍是 2。

## 二、裁決內容

**管理者 2026-10-15 選項逐字:「暫代灌入:開局把那兩條寫進池子(建議)」。**
協調者同時提供的另三個選項為「接受現況:開局無關係線、Φ 恆 0」、
「正式做:設計一份開局關係資料檔」、「退回:這段接線先不做」,**三個都被跳過。**

**條文**:

1. `BattleScreen._ready()` 在建立 `_affinity_pool` 之後、建構 `_phi` 之前,
   **依已解析完成的 `links`(來自 `AFFINITY_PATH` 的那份 `Array[AffinityLink]`)
   逐條對 `_affinity_pool` 寫入一筆記錄**,使池子的開局狀態與靜態檔描述的關係一致。
2. 極性對應:`POSITIVE` → 寫入正值;`NEGATIVE` → 寫入負值。
   🔴 **數值大小刻意不具意義** —— OQ-3 已裁決 `Φ` 只取 `value` 的符號、`amp` 恆為
   `AffinityLink.AMP_EXPECTED`(實測為 `1`,見 `src/gameplay/affinity/affinity_link.gd`
   該常數宣告),故任何同號數值都會得到完全相同的 `Φ`。**這一點是本案風險低的全部理由**:
   灌入不會偷偷產生一個沒有設計依據的具體數字。
3. **這是明文登記的暫代品,不是設計。** 未來劇情卡牌或存檔能真的寫入池子時,
   這段灌入要被換掉,不是再疊一層。程式碼註解必須寫明這件事與本檔路徑。

## 三、本裁決刻意不涵蓋的事

- **不設計任何新的資料格式。** 沿用現有的 `vs01_affinity_links.txt`,不新增檔案。
- **不碰存檔系統。** ADR-0004 維持 `Proposed`,不因本案被提前拉進範圍。
- **不修改 GDD。** 要不要把「開局關係從哪裡來」寫進 `design/gdd/affinity-position-chain.md`
  屬 `systems-designer` 網域,本裁決不代為決定。
- ⚠️ **沒有任何 lint、hook 或閘門會檢查這段灌入日後有沒有被移除** —— 與本專案其餘
  同類紀律一樣,買到的是「下一個人有明文可查對」,不是「下一個人一定會照做」。

## 四、與 2026-09-29 第 6 項裁決的關係(容易被看成同一件事,不是)

story-005 原文第 106 行起的「⚠️ 待決問題(本 story 作者發現,未經覆核)」段落,
講的是 `n_pair > 0` 但 `value == 0.0`(有互動記錄、正負剛好抵銷)。
🔴 **那一項管理者已於 2026-09-29 裁決完畢**,條文在
`production/epics/affinity-position-chain/EPIC.md` 的「✅ 第 6 項裁決」節
(當場查:`grep -n "第 6 項裁決" production/epics/affinity-position-chain/EPIC.md`)。
**story-005 原文那段「不得當成已裁決的事實實作」在 2026-09-29 之後已經過期,
但原文至今未更新** —— 讀 story 檔的人會以為它還開著。
本檔與那一項**無關**:那一項管「池裡有資料但淨值為 0」,本檔管「池裡根本沒資料」。
