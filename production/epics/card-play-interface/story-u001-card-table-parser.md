# Story U-001: `Card.from_csv_line()` + `Card.cards_from_text()` 卡表解析

> **Epic**: 卡牌介面、戰鬥選單與取消鍵(`production/epics/card-play-interface/EPIC.md`)
> **狀態**: 📋 Ready
> **層**: Gameplay(資料層 —— A 段,不碰按鍵,不受取消鍵同批義務約束)
> **型別**: Logic
> **估時**: S
> **依賴**: 無
> **解鎖**: U-003
> **波次**: 波 0(與 U-002 ∥ U-004 ∥ U-006 四路真平行 —— 四個不同檔,零交集)
> **Manifest Version**: 2026-09-09(`docs/architecture/control-manifest.md` 檔頭)

## Context

**權威來源**:`assets/data/cards/vs01_cards.txt` 檔頭欄位定義 + `src/gameplay/cards/card.gd` 的 doc comment。

🔴 **本單元沒有對應的 AC-U / AC-M 條文,這不是缺陷。** `design/ux/skill-card-play.md` 與
`design/ux/battle-menu.md` 兩份 UX 規格都不管轄資料載入(EPIC.md 第三節「逐單元 AC 數」節
明文登記)。驗收依據是上述兩份原始碼/資料檔的欄位定義與型別契約,不是任何一條 AC。

**Governing ADR**:N/A —— 純資料解析,不涉及任何跨系統契約或架構模式(依
`.claude/docs/coding-standards.md` 2026-09-01 裁決:ADR 只在跨系統契約時才寫,單一系統
內部技術細節寫在該系統設計文件裡)。

**既有型別(已存在,本 story 不新增,只讀)**:`src/gameplay/cards/card.gd` 的 `Card.Category`
enum(`TEMPORARY_STAT_MODIFIER`、`PERMANENT_AFFINITY_WRITE`)與兩個既有建構入口:

```gdscript
Card.new_temporary_stat_modifier(p_id, p_delta_atk, p_delta_def, p_duration_rounds)
Card.new_permanent_affinity_write(p_id, p_character_a, p_character_b, p_magnitude)
```

**資料檔**:`assets/data/cards/vs01_cards.txt`,固定欄位順序(8 欄):
`id,category,delta_atk,delta_def,duration_rounds,affinity_character_a,affinity_character_b,affinity_magnitude`

## 目標

寫一個能把 `vs01_cards.txt` 的每一列文字轉成一個 `Card` 實例的解析器(單列 `from_csv_line()`),
與一個能吃整份檔案文字、跳過空行與 `#` 註解列的整批版本(`cards_from_text()`)——沿用
`AffinityLink.from_csv_line()` / `links_from_text()`、`Unit.roster_from_text()` 這個既有慣例
形狀,不是新發明一套。做完之後,「這 8 張卡的機制數值」第一次有程式讀得到,而不是只存在於
一份沒人解析的文字檔裡。

## Implementation Notes

1. 🔴 **`Card` 的兩個建構入口各只收 4 個參數,而資料表有 8 欄(EPIC.md 陷阱一,轉錄)**:
   不能照 `Unit.from_csv_line()` 的「一個建構子吃全部欄位」形狀直接抄。解析器必須**先讀
   `category` 欄再分派**到兩個入口之一 —— `category == "TEMPORARY_STAT_MODIFIER"` 時只取
   `delta_atk`/`delta_def`/`duration_rounds` 三欄呼叫 `new_temporary_stat_modifier()`;
   `category == "PERMANENT_AFFINITY_WRITE"` 時只取 `affinity_character_a`/`affinity_character_b`/
   `affinity_magnitude` 三欄呼叫 `new_permanent_affinity_write()`。

2. 🔴 **`category` 絕不可寫 `Card.Category[value]`(EPIC.md 陷阱一,轉錄)**:已登記禁令
   `raw_enum_name_subscript_from_untrusted_string`(`docs/registry/architecture.yaml`)——
   **動態非法字串索引會當場中止呼叫函式**(2026-08-20 探針 C 實測)。**照抄
   `AffinityLink._polarity_from_string()` 的 `match` 形狀**(`src/gameplay/affinity/affinity_link.gd:138`)
   分派 `category` 字串,不得用 subscript。

3. 🔴🔴 **對實作者的明確警告:不要照抄第 2 點那個參考函式處理「未知字串」的那一段 —— 它本身
   有個問題,而它是既有程式碼,不是本 story 要修的東西(協調者已接手,見下)。**

   `AffinityLink._polarity_from_string()` 目前的「未知字串」分支是:
   ```gdscript
   match value:
       "POSITIVE":
           return Polarity.POSITIVE
       "NEGATIVE":
           return Polarity.NEGATIVE
       _:
           assert(false, "...unknown polarity '%s'" % value)
           return Polarity.POSITIVE
   ```
   `.claude/docs/coding-standards.md` 2026-09-15 新增的規則指出:**`assert()` 失敗會中止呼叫
   函式,並回傳該函式宣告回傳型別的「序數 0」**——不是真的執行到 `assert` 那行下面的
   `return`。`Polarity.POSITIVE` 剛好是 `enum Polarity { POSITIVE, NEGATIVE }` 的序數 0,
   所以這段程式碼**今天的實際行為是「未知字串 → 斷言失敗 → 靜默回傳 `POSITIVE`」**,而不是
   它讀起來像的「未知字串 → 中止並回報錯誤」。**這正是該規則點名的失效形狀:成功值(這裡是
   enum 的第一個宣告值)恰好排在序數 0,斷言失敗時反而看起來像是成功。**

   **`Card.Category` 有一模一樣的風險**:`enum Category { TEMPORARY_STAT_MODIFIER,
   PERMANENT_AFFINITY_WRITE }`,`TEMPORARY_STAT_MODIFIER` 是序數 0。若本 story 的
   `category` 分派函式照抄 `assert(false, ...)` 這個寫法,**一張 `category` 欄打錯字的卡
   (例如打成 `"Temporary_stat_modifier"` 大小寫不符)會被靜默當成合法的甲類卡處理**,而不會
   有任何看得見的錯誤——這比「崩潰」或「明確拒絕」都更危險,因為它會產生一張數值全部是
   預設值(`delta_atk=0, delta_def=0, duration_rounds=0`)、看起來正常但完全沒意義的卡。

   **本 story 的分派函式對未知 `category` 字串一律 `push_error()` 並跳過該列(不建構 `Card`,
   不加進回傳陣列)——不使用 `assert()`。** 理由:①`cards_from_text()` 是批次解析整份檔案,
   單一列壞掉不該讓其餘合法列也讀不到(比照 `AffinityLink.links_from_text()` 的
   log-and-continue 精神,但這裡更嚴格 —— `category` 決定整列後續怎麼解讀,沒有合理的
   「continue with a clamped value」可用,只能整列跳過);②`push_error()` 在所有建置皆會
   留下可觀測紀錄,不像 `assert()` 在某些建置下可能被移除(該疑慮已登記於既有的執行期防呆
   討論)。**`AffinityLink._polarity_from_string()` 本身這個問題不在本 story 授權範圍內,
   協調者已接手另行處理 —— 本 story 不修改該檔,只是不把同一個問題帶進新程式碼。**

4. 🔴 **`0` 在這張表上是三種不同的東西,不得收斂成同一個判斷(EPIC.md 陷阱二,轉錄)**:

   | 欄位 / 類別 | `0` 的意思 | 合法嗎 |
   |---|---|---|
   | 甲類的 `delta_def = 0` | 「這張牌不動這個軸」 | ✅ **正常值,不是 sentinel** |
   | 甲類的 `affinity_magnitude = 0` | unset sentinel | ✅ 合法 |
   | 丙類的 `affinity_magnitude = 0` | GDD 公式三的非法值 | 🔴 **會被寫入埠拒絕**(AC-9,
   skill-card-system epic 既有驗收條件,非本 story 職責) |

   **本 story 的解析器只負責「把欄位值原封不動搬進 `Card` 物件」,不判斷 `affinity_magnitude
   == 0` 在丙類卡上是不是合法**——那是既有 `PermanentAffinityWriteRules`/寫入埠
   (skill-card-system epic 已交付)的職責,寫入時才會拒絕。**解析器若自己加一層「0 就是
   沒填」的判斷,會把第一種(甲類 `delta_def=0`)也吃掉**,後果是一張純 ATK 卡被靜默當成
   資料錯誤處理——不崩潰、不報錯,只是那張卡的 `delta_def` 消失或整列被跳過。**本 story
   不得加這層判斷。**

5. 🔴 **`affinity_character_a` / `_b` 只是牌面敘事,機制上不讀(EPIC.md 陷阱三,轉錄)**:
   2026-09-10 管理者裁決:實際作用的配對由玩家在棋盤上兩步選定(S2p / S2q),
   `PermanentAffinityWriteRules.play()` 不讀這兩欄。**本 story 仍然要把這兩欄解析進
   `Card.affinity_character_a` / `_b`**(它們是牌面文字的資料來源,`card.gd` 的欄位本身就
   保留了這個用途),**只是不要誤以為解析出來的值會被機制讀取**——這是下一個讀這份 story
   的人容易誤解的地方,故在此明記。

6. **甲類卡的 `affinity_character_a`/`_b` 一律 `-1`(unset sentinel),丙類卡的
   `delta_atk`/`delta_def`/`duration_rounds` 一律 `0`**——`vs01_cards.txt` 檔頭已依此填寫,
   解析器照欄位值搬入即可,不需要額外驗證或補值。

7. **空行與 `#` 開頭的註解列必須跳過**——沿用 `AffinityLink.links_from_text()` 的既有慣例
   (見該檔對應方法的 doc comment)。

## Acceptance Criteria

*本單元沒有對應的 AC-U / AC-M 條文(EPIC.md 第三節明文登記,原因見上方 Context)。以下是
本 story 自訂的驗收基準,取自 `vs01_cards.txt` 檔頭與 `card.gd` doc comment 的型別契約:*

- [ ] `Card.from_csv_line()` 能把一行合法的甲類 CSV 文字轉成一個 `Category ==
      TEMPORARY_STAT_MODIFIER` 的 `Card`,四個欄位(`id`/`delta_atk`/`delta_def`/
      `duration_rounds`)與輸入逐一對應
- [ ] `Card.from_csv_line()` 能把一行合法的丙類 CSV 文字轉成一個 `Category ==
      PERMANENT_AFFINITY_WRITE` 的 `Card`,四個欄位(`id`/`affinity_character_a`/
      `affinity_character_b`/`affinity_magnitude`)與輸入逐一對應
- [ ] `Card.cards_from_text()` 解析 `vs01_cards.txt` 全文得到恰好 8 張 `Card`,6 張甲類、
      2 張丙類(對照現有資料檔)
- [ ] 甲類卡的 `delta_def = 0` 被正確保留為 `0`,不被當成「未填」而觸發任何跳過或警告
      (驗證第 4 點的區分)
- [ ] `category` 欄位是未知字串時,`push_error()` 被呼叫且該列不出現在回傳陣列中,其餘合法列
      仍正常回傳(驗證第 3 點——這條測試必須刻意構造一筆壞資料來證明)
- [ ] 空行與 `#` 註解列被跳過,不產生任何 `Card` 或錯誤

## Test Evidence

**型別**:Logic
**測試檔**:`tests/unit/gameplay/cards/card_from_csv_test.gd`

預期涵蓋:
- `test_from_csv_line_parses_temporary_stat_modifier_fields`
- `test_from_csv_line_parses_permanent_affinity_write_fields`
- `test_cards_from_text_parses_vs01_cards_txt_into_eight_cards`
- `test_delta_def_zero_is_preserved_not_treated_as_unset`(陷阱二核心宣稱)
- `test_unknown_category_string_logs_error_and_skips_line_others_still_parse`
  (陷阱一/警告核心宣稱——需要一筆刻意構造的壞資料列,不得用既有 `vs01_cards.txt`)
- `test_blank_and_comment_lines_are_skipped`

## Out of Scope

- **牌面顯示文字(`flavor_text`)解析**——屬 U-002,獨立檔案 `vs01_card_text.txt`
- **把 `Card` 陣列組成 `CardDeck` 並接進 `BattleController`**——屬 U-003
- **`affinity_magnitude == 0` 在丙類卡上的合法性驗證**——既有
  `PermanentAffinityWriteRules`/寫入埠職責(skill-card-system epic 已交付,AC-9),
  本 story 不重複實作
- **`category` 字串大小寫容錯或別名映射**——本 story 只接受欄位定義裡逐字寫的兩個字串,
  任何其他寫法(含大小寫不同)一律視為未知字串處理(見第 3 點)
- **修正 `AffinityLink._polarity_from_string()` 的 `assert()` 問題**——協調者已接手,
  不在本 story 授權範圍內

## Dependencies

- 依賴:無
- 解鎖:U-003(需要本 story 交付的 `Card.cards_from_text()`)
