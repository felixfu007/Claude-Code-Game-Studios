# QueryResult 範圍邊界:傳遞性讀取裁定(2026-11-12,technical-director)

> **地位**:審查/裁定紀錄,新檔。**未修改任何既有檔。**
> 第四節的「是否准許 story-040 不包」**不是**我能單獨裁決的事(理由見該節),已寫成白話選項交協調者請示管理者。
> ⚠️ **量測期間 `src/ui/battle/battle_screen.gd` 正在被並行修改**(story-040 實作中,未提交):
> 同一次查證中 `_cursor_attack_target_id` 的行號從 4994 漂到 5017。**本檔一律用函式名定位,不寫行號;
> 數字是 2026-11-12 當下工作樹(含未提交改動)的快照,要現值請重跑指令。**

## 一、問題

`docs/architecture/query-result-scope-boundary-2026-10-12.md`(下稱「範圍文件」)第二之一節判準 ① 寫
「回傳值在 `_refresh_view()` **單次執行內**被讀取」;第三節產生清單的方法卻是對 `_refresh_view()`
**函式體**做 grep。兩者在「被 `_refresh_view()` 呼叫的函式內部讀取」這一點上給出不同答案,文件未說明。
觸發點:story-040 的 `BattleController.attack_block_reason_for(target_id)`,由 `_update_tile_info_panel()`
讀取後寫進資訊卡文字,而 `_update_tile_info_panel()` 只在 `_refresh_view()` 內被呼叫。

## 二、讀過的原文(逐字錨點)

| 來源 | 逐字 | 定位 |
|---|---|---|
| 範圍文件 二之一 判準 ① | 「它的回傳值在 `src/ui/battle/battle_screen.gd` 的 **`_refresh_view()` 單次執行內**被讀取」 | `grep -n "單次執行內\*\*被讀取" docs/architecture/query-result-scope-boundary-2026-10-12.md` |
| 範圍文件 二之一 判準理由 | 「『同一次執行內讀到的那一組查詢』在定義上就是『會被合成同一張畫面的那一組』」 | `grep -n "在定義上就是" <同檔>` |
| 範圍文件 第三節 方法 | 「對 `_refresh_view()` 的函式體套用下列指令取得它讀了哪些查詢」 | `grep -n "的函式體套用" <同檔>` |
| ADR-0001 Core Rules #10b | 「**且被合併判讀為單一畫面的一組輸出** … **視為同一次查詢、共用同一份快照**」 | `grep -n "被合併判讀為單一畫面" docs/architecture/adr-0001-tactical-query-atomicity-contract.md` |
| ADR-0001 呈現層義務 | 「任何一組要合併呈現給玩家的查詢結果,渲染前須通過 `assert_same_version`」 | `grep -n "呈現層的義務" <ADR>` |
| ADR-0001 檢查項 6 / 閘門理由 | 以「**結算呼叫鏈**」為單位;並明寫「**靠搜尋 `await` 字樣抓不到**」 | `grep -n "呼叫鏈" <ADR>` |
| 範圍文件 八之二(10-12 管理者裁決) | 傷害預覽路徑缺 `is_stale` 檢查 →「**登記不對稱,不動程式**」;理由是兩條路徑在按下時都重新權威檢查 | `grep -n "登記不對稱,不動程式" <範圍文件>` |
| story-040 派工前查核第 1 點 | lead-programmer 建議不包,並要求實作者回報採用的讀法 | `grep -n "派工前查核" -A 14 production/epics/tactical-combat/story-040-attack-blocked-reason-line.md` |

## 三、裁定:**傳遞性讀法成立**(屬 technical-director 職權:解釋自己網域的操作型判準)

**判準 ① 的指稱對象是「`_refresh_view()` 的一次執行」,包含它同步呼叫的整棵呼叫樹;
第三節的函式體 grep 是產生清單的方法,而且是一個會漏的近似,不是定義。**

理由四條:

1. **條文本身用的是「單次執行」,不是「函式體」。** 被呼叫函式內的讀取,字面上就發生在那一次執行之內。
   範圍文件給判準 ① 的理由(同一次執行讀到的 = 會合成同一張畫面的)對被呼叫函式一樣成立;
   文件從未宣稱第三節的 grep 等於判準。所謂「字面讀法」其實是「方法讀法」。
2. **ADR-0001 的單位是「一張畫面」與「呼叫鏈」,不是語法位置。** #10b 管的是「被合併判讀為單一畫面的一組輸出」;
   檢查項 6 與閘門理由都以「呼叫鏈」為單位,而且明說只看字面 `await` 會漏。範圍文件是 ADR 的範圍界線,
   不能比 ADR 自己的分析單位更窄。
3. **函式體讀法會在「零行為改變的重構」下翻轉答案。** 把 `_refresh_view()` 裡任何一段抽成輔助函式,
   該段的查詢就安靜地離開範圍;反過來內聯又回來。**一個判準若在等價重構下改變答案,它就不是判準。**
   既有的 `_cursor_attack_target_id()` → `attack_targets()` 正是這個形狀:同一支 `attack_targets()`
   在函式體內被讀一次(受版本核對保護),經輔助函式又被讀一次(不受保護)。
4. **判準的安全性前提本來就必須在整棵呼叫樹上成立。** 範圍文件說安全性由「`_refresh_view()` 同步、無權威寫入」撐著;
   若只查函式體,被呼叫函式裡藏一個 `await` 就會讓整個前提失效而查不出來。
   **今天實測整棵樹成立**(見下表),所以傳遞性讀法不會把任何現有結論變成「不安全」——它只是把清單補完整。

**今日實測(不含註解行):呼叫樹內 16 個本檔函式,`await` / `call_deferred` / `commit_authoritative_change` 皆 0 命中。**

```bash
f=src/ui/battle/battle_screen.gd
for fn in _refresh_view _cursor_attack_target_id _is_move_preview_cell _guess_cell_state _displayed_guard_at \
          _update_tile_info_panel _build_attack_preview_text _update_relation_minimap _update_status_label \
          _update_consistency_counter _consistency_counter_text _update_guess_selector_ui \
          _set_tile_info_extra_line _set_tile_info_preview_mode _apply_tile_info_panel_layout _action_flag_for_state; do
  n=$(sed -n "/^\(static \)\?func $fn(/,/^\(static \)\?func [a-z_]/p" $f | sed '$d' | grep -v "^\s*#" \
      | grep -c "await\|call_deferred\|commit_authoritative_change"); echo "$fn code-hits=$n"; done
```

🔴 **順帶發現:範圍文件二之一節自己的驗證指令,今天已經不再回零。** 照它原樣對函式體 grep
(不濾註解)→ **5 命中**,5 行全是**引用這條禁令的註解**(例:「_refresh_view() 單次執行內沒有 await …」)。
這是 `coding-standards.md` 登記的「寫在註解裡的驗證指令會算到自己」同一形狀。結論(無真正讓出點)不變,
但**照文件重跑的人會看到 5 而不是 0**,可能誤判前提已破。草稿見第六節。

⚠️ **未驗證**:呼叫樹只追了 `battle_screen.gd` 本檔函式;被呼叫的 `BattleController` / `BattleState` /
`AffinityPhiProvider` 方法內部有無讓出點,**只讀了 `attack_block_reason_for()` 一支(無)**,其餘未逐支開檔。
`_relation_minimap_can_open` 內有 1 處 `_controller/_state/_phi` 字樣,未展開看是哪支。

## 四、story-040 結論

**依第三節的裁定,`attack_block_reason_for()` 三條判準全部成立,屬範圍內:**
① 經 `_update_tile_info_panel()` 在 `_refresh_view()` 單次執行內被讀;② 寫進 HUD 資訊卡文字;
③ 由盤面幾何計算導出(委派 `CombatRules.attack_block_reason`),不是裸存取。

**因此照 10-12 管理者裁決(「只改會被合併顯示的查詢」)的字面,它應該帶版本號。**
lead-programmer 的三條不包理由逐條判:

| 理由 | 判定 |
|---|---|
| 同步、無權威寫入 | **事實正確,但不是排除它的理由** —— 這個性質對範圍內那 5 支同樣成立,10-12 仍選擇包起來當防線。它解釋了「今天不會出事」,不解釋「為什麼它跟那 5 支不同」 |
| 單一列舉 | 回傳形狀與是否需要版本號無關 |
| 不與其他疊加圖層合成 | **部分成立,是三條裡唯一真正的區別。** 它是一行字,不是疊在棋盤上的一層格位。但它與攻擊範圍紅色角標**同時出現在同一個畫面**、講的是**同一件事**(打不打得到這個人);兩者不一致時玩家看到的是矛盾 —— 那正是 #10b 要防的形狀 |

**所以我不能直接判「不包 OK」。** 不包等於在範圍內新增一支例外,而既有的排除類別(四之一裸存取、四之二旗標、
四之三讀不到、四之四跨系統)都不涵蓋「計算導出 + 範圍內」。**新增例外改的是 10-12 管理者裁決的適用範圍,
不是解釋判準 —— 那要管理者點頭。** 白話選項如下(給協調者轉呈):

> **背景一句話**:畫面上「為什麼打不到」那行字,跟棋盤上的攻擊範圍標記,講的是同一件事。專案的規則是
> 這類「同一張畫面上一起顯示的計算結果」要附一個編號,好在將來萬一兩者算自不同時間點時抓得到。
> 今天程式結構保證它們一定同一時間點算出來,所以編號目前只是「將來的保險」。

| 選項 | 內容 | 代價 |
|---|---|---|
| **甲(推薦)不包,但登記成明文例外** | 維持現在的實作;在範圍文件登記這一支(連同下面已經存在的同類 `attack_targets_blocked_by_los()`)為「顯示用、按下時會重新檢查」的例外,並附兩個條件:結果不得存到下一次重繪;重繪流程裡一旦出現任何「等待」動作就必須改包 | 專案裡「該帶編號卻沒帶」的查詢再多一支,下一個人判斷時又多一種情況 —— 管理者 10-12 已被告知過這種代價 |
| 乙 包起來,但不加檢查 | 改成帶編號的型別,資訊卡那條路徑不檢查它 | 型別寫著「有保護」,實際沒有任何地方看它;這是本專案已登記過的「永遠回報通過的檢查」形狀。**不建議** |
| 丙 包起來,而且在資訊卡路徑加檢查 | 真正有保護 | 要先回答一個產品問題:「編號對不上時這行字要顯示什麼?」—— 10-12 管理者面對傷害預覽同一個問題時選了「不動程式」。而且只做這一支沒意義,要連同同一個函式裡的攻擊範圍、傷害拆解一起做 |

**推薦甲的理由**:與 10-12「傷害預覽路徑登記不對稱、不動程式」是同一個形狀、同一個理由
(輸入當下 `click_tile()` 會重新權威檢查,畫面上的字不會被拿去接受玩家輸入);
可逆性高 —— 列舉改包成結果型別是單檔小改,條件觸發時再做即可。
**實作已依「不包」開工,選甲則零重工。**

📌 範圍外但順帶看到(**未驗證,只提不判**):`attack_block_reason_for()` 的文件註解寫
「the same terrain-only occluder BattleState uses」,而它在 controller 內自己組了一個 `blocks_sight` lambda;
story-040 AC1 寫的是「其餘委派 `BattleState` → `CombatRules`」。另外「打得到嗎」在 `attack_targets()`(經
`_state.can_attack`)與本查詢(經 `CombatRules.attack_block_reason`)是兩條計算路徑。
**這是「同一規則兩份實作、只是今天答案一致」的風險,不是版本號的問題,QueryResult 擋不住它** —— 建議協調者另行確認
實作有沒有一條測試斷言兩者對同一目標給出一致答案。我未開 `battle_state.gd` 的視線實作比對。

## 五、既有傳遞性讀取清單(只列不修)

**方法**:對第三節那 16 個呼叫樹內函式逐一抽函式體、濾掉註解行,抓 `_controller.` / `_state.` / `_phi.` 呼叫。
**呼叫樹範圍實測**:`_update_tile_info_panel()` 的非註解呼叫點只有 1 處,在 `_refresh_view()` 內
(`grep -n "_update_tile_info_panel()" src/ui/battle/battle_screen.gd | grep -v ":\s*#"`)。

### 5-1 符合判準 ③(計算導出)的傳遞性讀取 —— 傳遞性讀法下屬範圍內

| # | 查詢 | 經由 | 樹內呼叫點 | 現況 |
|---|---|---|---|---|
| 1 | `move_targets()` | `_is_move_preview_cell()` | 2(`_refresh_view` 1、`_guess_cell_state` 1) | 型別已是 `MoveTargetsResult`,但只讀 `.cells`,**未過 `is_stale` / `assert_same_version`** |
| 2 | `attack_targets()` | `_cursor_attack_target_id()` | 2(`_refresh_view` 1、`_update_tile_info_panel` 1) | 同上,`AttackTargetsResult`,未檢查 |
| 3 | `preview_damage_breakdown()` | `_build_attack_preview_text()` ← `_update_tile_info_panel()` | 1 | 型別已是 `DamageBreakdownResult`,只讀 `.breakdown`,未檢查。🔴 **範圍文件四之三寫「整個 `src/ui/` 也沒有任何地方讀它們」——今天已不成立**(`grep -rn "breakdown" src/ui/ --include=*.gd` 現有命中) |
| 4 | `lone_guard_if_at()` | `_displayed_guard_at()` | 3(`_refresh_view` 2、`_update_tile_info_panel` 1) | 回傳裸 `int`。依其文件註解是計算(內含 d_min 迴圈),**我判為符合 ③;未開函式體逐行確認** |
| 5 | `attack_block_reason_for()` | `_update_tile_info_panel()` | 1 | story-040 新增,裸列舉 |

**合計 5 支**(1~3 已是結果型別、缺的是呈現層檢查;4~5 連型別都沒有)。

### 5-2 不屬範圍(依既有排除類別)

- 好感度(範圍文件第六節,跨系統缺口):`_phi.links()`(經 `_displayed_guard_at`)、`_phi.positions()`(經 `_update_tile_info_panel`)、`_phi.phi()`(經 `_build_attack_preview_text`)
- 裸存取/旗標(四之一、四之二):`unit_at` / `position_of` / `unit_by_id` / `phase` / `selected_unit` / `unit_action_state`(轉呼叫 `_order.unit_action_state`,實測一行)、`_state.board.get_terrain` / `get_move_cost` / `blocks_sight`
- 非戰棋查詢:`_guess_tracker.*`(猜測統計)

### 5-3 🔴 函式體本身的漂移(與傳遞性無關,**函式體讀法下也已經漏**)

範圍文件第三節表列 5 支;今天對函式體重跑第三節的指令,另有三支不在表上:

| 查詢 | 判準 ③ | 現況 |
|---|---|---|
| `move_targets_breakdown()` | 計算 | ✅ 已包且已併入 `_refresh_view` 的版本核對 —— **只是範圍文件的表沒更新** |
| `attack_targets_blocked_by_los()` | 計算 | 🔴 **裸 `Array[Vector2i]`,不帶版本號**。程式碼註解自承「未遷移為 QueryResult」,以同步同快照為理由。**範圍文件、`architecture.yaml` 皆零登記**(`grep -rn "attack_targets_blocked_by_los" docs/registry/architecture.yaml docs/architecture/*.md` 零命中)—— 這是 story-040 想做的事的**未登記前例** |
| `unit_action_state()` | 旗標轉呼叫 | 屬四之二類,只是沒列名 |

```bash
sed -n '/^func _refresh_view/,/^func [a-z_]/p' src/ui/battle/battle_screen.gd | sed '$d' \
  | grep -o "_controller\.[a-z_]*(\|_state\.[a-z_]*(\|_phi\.[a-z_]*(" | sort | uniq -c | sort -rn
```
2026-11-12 輸出 20 支相異查詢(10-12 時為 17)。

**「補」該補什麼,我不代為決定**:1~3 缺的是呈現層檢查,而那正是 10-12 管理者對傷害預覽路徑裁「登記、不動程式」的同一件事;
4、5 與 5-3 的 `attack_targets_blocked_by_los()` 缺的是型別。若管理者在第四節選甲,這 6 支可用同一條例外一次登記。

## 六、範圍文件加註草稿(未寫入,待協調者請示)

**插入位置建議**:範圍文件「二之二」節標題之前(二之一末尾)。原文零刪除、只新增。

> ### 二之一補註(2026-11-12 technical-director 裁定):判準 ① 涵蓋整棵同步呼叫樹
>
> **判準 ① 的「`_refresh_view()` 單次執行內」包含它同步呼叫的所有函式。** 第三節對函式體 grep 的方法
> 是產生清單的近似,**會漏掉經輔助函式讀取的查詢**,不是判準本身。理由:條文寫的是「單次執行」;
> ADR-0001 #10b 的單位是「一張畫面」;函式體讀法會在抽函式這種零行為改變的重構下翻轉答案。
> 裁定全文與 2026-11-12 的呼叫樹清單:`docs/reviews/query-result-scope-transitive-ruling-2026-11-12.md`。
>
> **連帶兩件事**:
> 1. 第二之一節「無 `await`/提交/`call_deferred`」這條前提,**必須對整棵呼叫樹成立**,不只函式體。
> 2. 🔴 該節的驗證指令**今天會回 5 而不是 0** —— 5 行全是引用本禁令的註解。重跑時請濾註解並逐函式查:
>    `... | grep -v "^\s*#" | grep -c "await\|call_deferred\|commit_authoritative_change"`(逐函式迴圈見上述裁定檔第三節)。
>
> ⚠️ 本補註只改「怎麼讀判準」,**不改任何一支查詢的處置** —— 呼叫樹內新找到的範圍內查詢怎麼辦,
> 見上述裁定檔第四、五節與其後的管理者裁決。與本文件其餘規則一樣,沒有自動檢查會攔。

若管理者選甲,另需在第四節新增一小節(例外類別 + 兩個條件 + 6 支名單),草稿待裁決後再擬,避免先寫出未裁決的內容。

## 七、未驗證項

| # | 項目 | 狀態 |
|---|---|---|
| 1 | 被呼叫的 gameplay 側方法(除 `attack_block_reason_for`)內部無讓出點 | 未開檔 |
| 2 | `lone_guard_if_at()` 屬計算導出 | 只讀文件註解,未讀函式體 |
| 3 | `_relation_minimap_can_open` 內那 1 處查詢是什麼 | 未展開 |
| 4 | controller 內的視線 lambda 與 `BattleState` 是否同一份規則;`attack_targets()` 與 `attack_block_reason_for()` 是否有一致性測試 | 未查 |
| 5 | 所有行號/計數 | 並行修改中的工作樹快照;以指令重跑為準 |
| 6 | `_build_attack_preview_text` 的呼叫點是否只有 `_update_tile_info_panel` 一處 | grep 非註解命中只有 1 處,但檔案正在被改 |
