# src/ 內 assert() 的 release 風險盤點(2026-11-11)

背景:`prototypes/assert-release-probe-2026-11-11/README.md`(A 級)—— release 匯出整條移除 `assert()`(運算式不求值、函式照常往下);debug 下失敗則中止並回傳宣告回傳型別的 ordinal 0;release 下**整數**除以零行程無聲結束(exit 127)。

## 盤點方法

- 樣式(Grep,ripgrep):`^\s*[^#\s].*\bassert\(|^\s*assert\(`,範圍 `src/**/*.gd`。排除以 `#` 起首的整行註解(含 `##` 文件註解),所以註解裡「assert()」的敘述不會被算進來。
- 命中數:**18**(逐呼叫計,多行 assert 以起始行計)。逐筆讀過原碼,18 筆皆為真呼叫。
- 本檔只在 `docs/reviews/`,不在 `src/`,所以本檔文字不會污染上述樣式的命中數。
- 「release 後果」欄凡未經引擎量測、純依程式碼推論者,一律標「推論」。**只有「assert 被整條移除、函式照常往下」是 A 級**;「陣列越界後函式回傳什麼」等本次**未量測**。

## 盤點表

| 檔:行 | assert 條件 | 守的是什麼 | 呼叫端能否傳出違反值(證據) | release 下違反時的後果 | 建議 |
|---|---|---|---|---|---|
| `gameplay/units/unit.gd:192` | `fields.size()` 為 11 或 12 | 資料檔(名冊 `vs01_roster.txt` 一列的欄數) | **能**。唯一呼叫端 `Unit.roster_from_text`(unit.gd:249)把檔案逐列餵入,不預先驗欄數;資料檔可被修改者寫錯。 | 欄數不足:後面 `fields[N]` 越界(推論:script error、函式中止、回 null,而 `roster_from_text` 對 null 會整份拒絕並印行號,所以大概仍「響亮」,但靠的是引擎越界錯誤而非明文檢查,未量測)。欄數過多(>12):**靜默接受**,多的欄位被忽略。 | **改 push_error+return**(`return null`;下游 null 路徑已存在) |
| `gameplay/affinity/affinity_link.gd:90` | `fields.size() == FIELD_COUNT` | 資料檔(好感度連結表一列欄數) | **能**。唯一呼叫端 `links_from_text`(affinity_link.gd:164),不預驗。 | 欄數不足:`fields[3]` 越界(推論,同上);過多:靜默接受。 | **改 push_error+return**(`return null`,`links_from_text` 已處理 null) |
| `gameplay/affinity/affinity_link.gd:107` | `unit_a != unit_b` | 資料檔(連結表語意:不可自己配自己) | **能**。同上,資料檔內容。查不到其他防線(此後僅 amp 範圍檢查,走 push_warning)。 | **靜默接受自配連結**(assert 移除後函式照常 return link)。後續 `involves`/`partner_of` 對自配連結會回自己。 | **改 push_error+return**(`return null`) |
| `gameplay/affinity/affinity_link.gd:184` | `involves(unit_id)` | 內部不變式(`partner_of` 前置條件) | 查過兩個呼叫端:`affinity_rules.gd:223` 前一行有 `if not link.involves(unit_id): continue`;`card_play_session.gd:442` 在 `if link.involves(first)` 內。**皆已守衛**,內部計算,資料檔無法繞過。 | 若違反:回傳 `unit_a`(錯的夥伴),靜默。目前不可達。 | 無需處理(保留 assert 當 debug 警戒) |
| `ui/cursor/cursor_state.gd:1110` | `target != null` | 內部不變式(呼叫契約) | 緊接其後有 `if target == null: return INVALID_SURFACE_TYPE`,上方註解明述「assert 在 release 會被剝除,所以另加明文分支」。 | release:assert 消失,明文分支接手,**行為正確**。 | 無需處理(這是本專案正確寫法的範例) |
| `ui/cursor/cursor_target.gd:40` | `other != null` | 內部不變式 | 呼叫端:`cursor_state.gd:1073` 前有 `expected == null or` 短路;`cursor_state.gd:1179` 前有 `if old == null or new == null: return old != new`(註解明述原因)。**皆已守衛**。 | 若違反:`other.surface` 對 null 解參考 → script error,函式中止,bool 回 false(推論)。目前不可達。 | 無需處理 |
| `ui/cursor/cursor_types.gd:240` | `board_width > 0` | 內部參數(`encode_tile`) | 所有呼叫端(battle_screen.gd:1516/2173/3828/3891/3958)皆傳 `BoardCoords.BOARD_COLS`,常數 13(board_coords.gd:55)。**不可能為 0**。 | 此函式只用乘法,不除;違反不致行程結束。 | 無需處理 |
| `ui/cursor/cursor_types.gd:244` | `cell.x` 在 `[0, board_width)` | 內部參數 | battle_screen.gd 的呼叫端:1516/3958 先 `BoardCoords.is_in_bounds(cell)`;3891 `positions[next_id]`(棋子位置,來自棋盤狀態,未逐一追到合法性,**查不到**是否可越界)。 | release:靜默編出錯誤 tile id(與鄰格重複或換列)。 | 無需處理(低);3891 的來源若要確認屬另案 |
| `ui/cursor/cursor_types.gd:248` | `cell.y >= 0` | 內部參數 | 同上。 | release:靜默編出負 id,之後 `decode_tile` 的 `id >= 0` 前置也被移除,`%`/`/` 對負數不致當機。 | 無需處理 |
| `ui/cursor/cursor_types.gd:260` | `board_width > 0`(`decode_tile`) | **除法前守衛**:`id / board_width`、`id % board_width` 為**整數**除法 | 呼叫端(battle_screen.gd:2186/3824/3883/3994/4504)全傳 `BoardCoords.BOARD_COLS` = 13 常數;**不可能為 0**。 | 若為 0:release 下**行程無聲結束(exit 127)**(A 級,見探針)。但目前常數 13,不可達。 | **無需處理**,但這是全庫唯一「除法前守衛」且後果最重;若日後 board_width 改成可變/資料驅動,必須先升級為 push_error+return |
| `ui/cursor/cursor_types.gd:264` | `id >= 0` | 內部參數 | 同上,id 來自 `CursorTarget.id`(由 `encode_tile` 產生或 cursor 狀態)。 | release:負 id 解出負座標,不當機。 | 無需處理 |
| `ui/cursor/mouse_reclaim_threshold_config.gd:97` | `assert(false, ...)`(列舉成員未對應) | 內部不變式(列舉與查表同步) | 後面緊接 `return 1.0`,**release 下 assert 被移除後有明文回傳**;註解明述 AC-46b 另管非 debug 偵測。`SurfaceType` 現有 4 成員皆有對應。 | release:靜默回 1.0。 | 無需處理(已有明文 fallthrough) |
| `ui/cursor/mouse_reclaim_threshold_config.gd:108` | `value > 0.0` | 調校值(`@export` 欄位,預設 75.0) | 唯一建構點 `cursor_state_host.gd:302` 用 `new()` 取預設值,全庫 grep 查無對四個 `*_threshold_px` 的賦值(`grep -rnE "(board_tile\|…)_threshold_px\s*=" src`,命中僅欄位宣告)。目前**不可達**;若日後改由 `.tres`/資料檔載入則算外部輸入。 | 值為 0:`threshold_mouse_reclaim_policy.gd:134` 的 `net_displacement_px / threshold_px` 是 **float** 除法(推論:IEEE 結果為 inf/nan,不是整數除零那條死路,**本次未量測**);`clampf` 後進度被夾成 1.0 或 0.0,表現為游標「立即回收」或「永遠不回收」。 | 保留(日後改資料驅動時再升級為 push_error+夾限) |
| `gameplay/cards/card.gd:215` | 欄數介於 8~10 | 資料檔(`vs01_cards.txt` 一列欄數) | **能**。唯一呼叫端 `Card.cards_from_text`(card.gd:296)不預驗。 | 欄數不足:後續 `fields[N]` 越界(推論);過多:靜默接受。 | **改 push_error+return**(`return null`,`cards_from_text` 已處理 null) |
| `gameplay/cards/card_deck.gd:115` | `not _pending_discard` | 內部不變式(呼叫端須先處理強制棄牌) | 呼叫端 `battle_state.gd:900` `begin_player_turn()`;其註解稱兩個呼叫端的義務是「不會在待棄牌時再呼叫」。**查不到**自動化證據證明此義務必定成立。 | release:**靜默繼續抽牌**,手牌超過 `HAND_SIZE_LIMIT+1`(函式註解自述 GDD 無此規則)。不致當機。 | 保留(內部不變式、後果可見);若要在 release 保響亮,改 push_error+return(會變成「跳過抽牌」,與該函式註解「寧可響亮」的意圖需管理者/設計確認) |
| `gameplay/cards/card_play_session.gd:346` | `moved`(`_deck.play_card` 回 true) | 內部不變式(選卡後到確認前卡未離手) | 同步流程內,`confirm()`(battle_controller.gd:726)呼叫;前面已執行寫入。**查不到**外部能在此間搬走卡的路徑,也未逐一追蹤所有 `_deck` 寫入點。 | release:**寫入已發生、卡未移走,仍 `_reset_to_closed()` 並回 true**,卡可能重複使用(推論)。 | 保留;或改為 `if not moved: push_error(...)`(不 return,因寫入已完成,須另案決定如何收尾) |
| `gameplay/cards/card_text.gd:74` | 欄數 == 2 | 資料檔(`vs01_card_text.txt`,`split(",", true, 1)`,沒有逗號時只有 1 欄) | **能**。唯一呼叫端 `battle_screen.gd:1860` 直接讀檔後解析;檔頭註解自陳此表「壞列要不要整表中止」尚未裁決。 | 缺逗號:`fields[1]` 越界(推論:script error、函式中止,回傳型別為 Dictionary,後果依引擎而定,**未量測**)。無逗號之外的情形不會觸發(`split` 上限 1 次,最多 2 欄)。 | **改 push_error+continue**(跳過該列;屬展示文字,與該檔註解「未裁決」相容,請設計確認) |
| `gameplay/cards/permanent_affinity_write_rules.gd:135` | `card.category == PERMANENT_AFFINITY_WRITE` | 內部不變式(呼叫契約) | 唯一呼叫點 `card_play_session.gd:331`,其上一行即 `if _selected_card.category == Card.Category.PERMANENT_AFFINITY_WRITE:`。**已守衛**。 | 若違反:release 下對非該類卡直接寫入好感度,靜默。目前不可達。 | 無需處理 |

## 彙總

- 總數:**18**。
- 建議分布:**改 push_error+return/continue:5**(unit:192、affinity_link:90、affinity_link:107、card:215、card_text:74)、**保留:3**(card_deck:115、card_play_session:346、mouse_reclaim:108)、**無需處理:10**(affinity_link:184、cursor_state:1110、cursor_target:40、cursor_types 五處、mouse_reclaim:97、permanent_affinity_write_rules:135)。合計 5+3+10 = 18。
- 全庫**沒有任何一處**是「除法前守衛且可達」。唯一的整數除法守衛(`cursor_types.gd:260`)目前因常數 13 不可達。
- 本批最集中的風險形狀只有一個:**「資料檔一列的欄數/語意檢查用 assert」**(5 處,三份資料檔 + 一份展示文字檔)。資料檔是外部輸入,release 下檢查消失,後果是靜默接受(過多欄、自配連結)或越界(不足欄,後果推論未量測)。

## 建議處置優先序(必修最多 5 條)

1. `affinity_link.gd:107` 自配連結:release 靜默接受,且是「語意錯誤」類,不靠任何下游錯誤兜底。
2. `unit.gd:192` 名冊欄數:release 下欄數過多靜默接受、不足依賴越界錯誤。
3. `affinity_link.gd:90` 連結表欄數:同上。
4. `card.gd:215` 卡表欄數:同上。
5. `card_text.gd:74` 牌面文字缺逗號:越界後行為未量測,且 `battle_screen.gd:1860` 接收端沒有對應的失敗處理。

(上述 1~4 的修法一致:`if 不符: push_error(...); return null`,而三個 `*_from_text` 呼叫端已有 null→整表拒絕的路徑,**零新增下游改動**。)

## 是否需要新工作單

建議**開一張小工作單**(只建議,本盤點不改程式)。Affected Files 草案:

- `src/gameplay/units/unit.gd`
- `src/gameplay/affinity/affinity_link.gd`
- `src/gameplay/cards/card.gd`
- `src/gameplay/cards/card_text.gd`(改為 push_error+continue,需設計確認「壞列要不要整表中止」)
- 對應測試:`tests/unit/` 下各解析器測試補「欄數不符/自配連結回 null」的案例(是否已有同名測試,本次未查)

交付須依 CLAUDE.md 附 `ENGINE EXIT` 與 `Overall Summary` 原始三行。注意:這類測試在 debug 下原本就會被 assert 中止,改成 push_error 後需讓測試能觀察到 null 回傳與 error 輸出,GdUnit4 對 `push_error` 可能判失敗,實作者需先探針確認(本次未查)。

## 未查證、誠實登記

- `cursor_types.gd:244/248` 在 `battle_screen.gd:3891` 的 `positions[next_id]` 是否必在界內:**查不到**。
- 「陣列越界後函式回傳什麼」「Dictionary 回傳型別函式中止後的值」:**未量測**,全為推論。
- float 除以零在 release 下是否不死:推論(IEEE),**未量測**;探針只量了整數除零。
- 其他解析器(`campaign_sequence.gd`、`support_conversation_record.gd`)的欄數檢查不是 assert(樣式零命中),本次沒讀它們用什麼。

## 進度:已核 18 / 共 18
