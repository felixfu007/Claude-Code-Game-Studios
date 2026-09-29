# 卡牌介面 epic:5 張「狀態欄停在 Ready」工作單的對帳(2026-09-29)

> **發動原因**:第六十六批交接寫「17 張全部實作完畢」,但協調者接手對帳時實測
> **18 張裡有 6 張狀態欄仍為 `📋 Ready`**(U-008/009/010/012/016/018)。U-016 另有進行中的
> 裁決,本檔處理其餘 5 張。
> **管理者 2026-09-29 裁決**:「我逐張對帳後,一次請你裁決」——本檔是那份對帳。

## 結論先寫

| 工作單 | 交付物 | 宣告的測試 | 判定 |
|---|---|---|---|
| U-008 選單開啟守門 | ✅ 在 | ✅ 兩支都在(15 + 9 條) | **可判完成** |
| U-009 結束回合列接線 | ✅ 在 | ✅ 在(14 條) | **可判完成** |
| U-010 離開遊戲確認 | ✅ 在 | ⚠️ 在,但工作單寫錯路徑(17 條) | **可判完成(附一處純文件更正)** |
| U-012 手牌展開＋卡牌細節 | ✅ 在 | 🔴 **工作單列的 3 條測試,名稱一條都對不上** | 🔴 **不可判完成,見下** |
| U-018 敵方階段逐步演出 | ✅ 在 | ✅ 在(11 條) | **可判完成(附一項 ADVISORY 缺口)** |

🔴 **這 5 張從未經過管理者的判完成裁決**(U-013/U-014/U-015 都有,且逐字記錄在案)。
U-008 的工作單檔案**自建立那天之後就沒有再被任何提交碰過** —— 實作它的提交 `8cdc926` 沒有動它。

## 查法(可重跑,不要相信本檔的轉述)

```bash
# 狀態欄現值
for f in production/epics/card-play-interface/story-*.md; do
  printf "%-52s " "$(basename $f)"; grep -m1 "^> \*\*狀態\*\*" "$f" | cut -c1-40; done

# 某張工作單宣告的測試檔是否存在
grep -oE "tests/[a-z]+/[a-z_/]*[a-z_]+\.gd" production/epics/card-play-interface/story-u010-*.md
```

## 🔴 U-012:不可判完成的兩個理由

### 理由一:AC-U8(BLOCKING)只做了一半,而沒做的那一半在畫面上零實作

AC-U8 原文(`design/ux/skill-card-play.md`):

> 權威寫入進行中按 `開手牌` → 手牌**未開啟**,且出現的拒絕回饋與「目標不合法」的拒絕回饋**外觀不同**

- **前半(閘門)已驗**:`tests/integration/gameplay/cards/card_play_session_test.gd` 的
  `test_ac14_authoritative_write_in_progress_blocks_open_hand_synchronously`。
  ⚠️ 注意它**掛在 `ac14` 這個編號下,不是 `AC-U8`** —— 所以用 AC 編號搜尋會搜不到它。
- 🔴 **後半(兩種拒絕回饋外觀不同)在 `src/ui/` 裡零實作。** 實測:

```bash
grep -rn "reject" --include=*.gd src/ui/
```
命中的**全部**是 `_diagnostic_*` 計數器與 getter。`_on_battle_menu_open_rejected()` 只把結果
記進診斷欄位,**沒有任何東西被畫出來**。畫面上不存在任何拒絕回饋外觀,
所以「兩種外觀不同」這個條件**結構上無法成立**,不是還沒測,是還沒有東西可測。

### 理由二:AC-U10(BLOCKING)依賴一個不存在的功能

AC-U10 要求「四種螢幕 × 字級 **75% / 100% / 150%** 共 12 組」,而規格自己在 UX-5 登記:

> **字級可調 75%~150% 的功能尚未實作** —— `HudLayout.font_size()` 目前無玩家可調係數

規格並明文「**AC-U10 的 12 組不得抽樣**」。亦即今天只能驗 12 組裡的 4 組(100% 那一檔),
**而規格本身禁止把那 4 組當成通過。**

### U-012 的測試名稱對不上(不是缺測試,是對不上)

| 工作單寫的 | 實際存在的 |
|---|---|
| `test_open_hand_rejected_when_authoritative_write_in_progress_check_returns_true` | `test_ac14_authoritative_write_in_progress_blocks_open_hand_synchronously`(不同檔案) |
| `test_input_not_blocked_during_expand_animation` | `test_move_cursor_works_while_expand_tween_is_still_running` |
| `test_open_hand_transitions_session_to_selecting_card` | 🔴 **未找到同義者**(`grep -rn "func test_open_hand" tests/` 零命中) |

📌 **這比「少一條測試」更值得記**:工作單與測試之間**沒有任何機械可查的對應關係**,
第三方無法用工作單去核對測試。這正是本專案反覆登記的形狀 —— 結論被抄走,實作後來變了,沒人發現。

## U-018:一項 ADVISORY 缺口

**AC-E5**(UI,ADVISORY):「真實遊戲畫面截圖:敵方階段進行中的一格,手牌帶呈現 S5『不可用』外觀」。
**這張截圖從未拍過**(`production/qa/evidence/` 無對應檔案)。
AC-E1~E4 皆有測試引用。**這與本專案「連續四張沒人看過畫面」是同一件事的另一個出口。**

## U-010:一處純文件更正

工作單寫的測試路徑是 `tests/integration/ui/battle_menu_leave_confirmation_test.gd`,
實際在 `tests/integration/ui/menu/battle_menu_leave_confirmation_test.gd`(少一層 `menu/`)。
測試本體存在、17 條。**純路徑筆誤,不影響交付。**

## 本檔沒有做的事(誠實揭露)

- **沒有逐條核對每個 AC 的測試是否真的驗到它宣稱驗的東西。** 本檔查的是
  「交付物存在嗎 / 工作單列的測試存在嗎 / AC 有沒有被任何測試引用」,**不是測試品質**。
  要那個請跑 `/test-evidence-review`。
- **沒有重跑測試套件。** 本檔全部是靜態查證(`grep` / `ls` / `git log`)。
