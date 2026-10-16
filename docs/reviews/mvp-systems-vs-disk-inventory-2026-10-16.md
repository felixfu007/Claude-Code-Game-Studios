# MVP 剩餘系統:索引說的 vs 磁碟上真的有的(2026-10-16 對帳)

> **為什麼有這份文件**:2026-10-16 當天,協調者在**準備動工之前**兩次撞到
> 「設計文件的前提已經悄悄變假」,而兩次都是在開工前一刻才發現的。
> 第三次之前先對一次帳,比第三次再發現便宜。
>
> **這份文件只登記事實,不下任何設計判斷,也不修改 `systems-index.md`** ——
> 改那張表是另一次動作,需要先問。

## 一、對帳結果:四個剩餘 MVP 系統,**兩個的狀態欄與磁碟不符**

| # | 系統 | 索引寫的 | 磁碟實況 | 對得上? |
|---|---|---|---|---|
| 8 | 支援對話系統 | Not Started | 只有一個 enum 成員 `SUPPORT_CONVERSATION`(寫入來源型別),無系統 | ✅ **對** |
| 9 | 好感度視覺呈現 UI | Not Started | 🔴 **棋盤連線已經做好了**(見第二節) | ❌ **不對** |
| 10 | 戰鬥 HUD(僅預判標記) | Not Started | 🔴 **好感度/傷害預覽已經做好了,而且它讓預判標記的前提失效**(見第三節) | ❌ **不對** |
| 11 | 支援對話 UI | Not Started | 零實作(搜尋命中皆為無關字詞) | ✅ **對** |

查法(當場可重跑):
```bash
grep -rln "support_conversation\|SUPPORT_CONVERSATION" src/ --include=*.gd     # → 只有 affinity_types.gd
grep -n "func set_affinity_lines\|enum LineTone" src/ui/battle/board_view.gd   # → 都在
grep -n "_is_move_preview_cell\|format_affinity_preview" src/ui/battle/battle_screen.gd
```

## 二、#9 好感度視覺呈現 UI —— 已建與未建的分界

**已建(在 `src/ui/battle/board_view.gd`)**:
```
232:enum LineTone { POSITIVE, NEGATIVE, MUTED }
388:@onready var _affinity_line_layer: Node2D = $AffinityLineLayer
560:func set_affinity_lines(lines: Array[Dictionary]) -> void:
```
連同深色襯底描邊技法、圖層順序(連線畫在棋子層之上)、以及
`battle_screen.gd` 的好感度預覽文字(Mode A/B)。

**未建**:**關係圖迷你地圖**(跨棋子比較介面)。
```bash
grep -rin "minimap" src/ --include=*.gd    # → 只有游標系統的門檻設定,見下
grep -rn "迷你地圖" design/ux/*.md design/gdd/game-concept.md | wc -l    # → 8
```
**設計文件提了 8 次,`src/` 零實作。**

### 🔴 一個值得單獨記的形狀:消費端的鉤子已經在了,生產端還不存在

```
src/ui/cursor/mouse_reclaim_threshold_config.gd:32  @export var relation_minimap_node_threshold_px: float = 75.0
src/ui/cursor/mouse_reclaim_threshold_config.gd:83      CursorTypes.SurfaceType.RELATION_MINIMAP_NODE:
```
**游標系統已經替關係圖迷你地圖預留了表面型別與專屬門檻值,而那個迷你地圖本身不存在。**
📌 這與 `docs/tech-debt-register.md` 已登記的同類形狀是一家人
(該檔記載「消費端(真正會卸載的 UI 表面)一個都還不存在,所以『每個』現在恆真而無意義」)
—— 只是方向相反:**那次是規則沒有消費端,這次是消費端沒有生產端。**

⚠️ **這表示 #9 若要動工,不是「從零開始」,而是「接上一個已經替它開好的孔」** ——
動工前必須先讀那個表面型別的既有契約,不能當成新設計。

## 三、#10 戰鬥 HUD —— 前提曾經失效,已於同日裁決處置

**已建**:好感度預覽(`format_affinity_preview`,Mode A「if I move here」)、
好感度現值(Mode B)、傷害預覽(Mode C)。

🔴 **而「預判標記」的定義是「玩家移動前先標記預期效果,系統量一致率」**
(`game-concept.md:446`,驗收協議 1,門檻 80%)。
**畫面已經把答案寫在那裡,玩家不是在預判,是在讀字。**

**成因**:2026-07-29 裁決預判標記時,那個預覽還不存在;後來另一條工作線做出來了,
**中間沒有人對帳**。

✅ **2026-10-16 管理者裁決「先下注再揭曉」**,規格已據此改寫
(`design/quick-specs/battle-hud-prediction-marker.md`),**本項已結案**,
列在這裡是作為對帳樣本,不是待辦。

## 四、這份對帳【不涵蓋】什麼(誠實揭露)

- **只對了四個剩餘 MVP 系統**,沒有對已完成的系統(#1~#6)。
  已完成系統的索引狀態欄是否仍然準確,**未查**。
- **只用 `grep` 對文字,沒有跑引擎。** 「磁碟上有這個 class / 這個方法」不等於
  「它在遊戲裡真的會被執行到」—— 2026-10-16 的 `story-020` 正好示範了
  一段接好線的程式可以完全不被觸及(強制棄牌凍結點)。
- **沒有判斷任何系統「該不該做」或「範圍該多大」。** 那是設計裁決。
- 🔴 **沒有修改 `design/gdd/systems-index.md`。** 第一節表格指出它有兩列與磁碟不符,
  **但改那張表需要先問** —— 它是跨系統的權威索引,不是隨手可改的筆記。

## 五、給下一個動工的人的一句話

> **開任何一張新系統的規格之前,先用 `grep` 對一次「索引說 Not Started 的東西,
> `src/` 裡是不是已經有了」。** 2026-10-16 兩次撞牆都是這一步省下來的代價,
> 而兩次都是在派工前一刻才發現 —— 其中一次已經寫完第一版規格才發現前提不成立。
