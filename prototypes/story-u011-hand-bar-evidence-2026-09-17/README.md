# Story U-011 手牌縮圖帶 —— AC-U4 後半擷圖證據 driver

> PROTOTYPE - NOT FOR PRODUCTION / 拋棄式證據擷取驅動,不是 HandBar 的正式實作
> **日期**:2026-09-17
> **執行者**:ui-programmer,本機直接執行 Godot 4.7.1(有實體 GPU,非 headless)

## 驗證的假設(hypothesis)

`design/ux/skill-card-play.md` AC-U4 後半:「手牌 0 張(S7)的畫面,與 S5『不可用』
的畫面外觀可區分(兩張截圖並列比對,轉灰階後仍可區分)」。本 driver 要驗證的假設是:
**`HandBar` 在 S7(空手牌,常態可用)與 S5(不可用)這兩種輸入下,渲染出的畫面在灰階
下確實有可測得的差異,而不是只有色相不同**(`P-F3` 無例外)。

## 🔴 兩張圖的證據強度不同 —— 這是本 driver 存在的理由之一,不是事後補充

- **S7**:走【完整、真正的正式場景】`res://src/ui/battle/BattleScreen.tscn`
  (不是複本、不是重新實作)。真實卡表 `assets/data/cards/vs01_cards.txt`
  實測有 8 張卡(`grep -vc "^#\|^$"` 逐字輸出:`8`),遠多於
  `CardDeck.OPENING_HAND_SIZE`(5),所以正式場景走正常真實載入路徑時**永遠**會
  發滿 5 張 —— S7 用真實資料自然發生不了。做法:讓場景先正常 `_ready()`(走完整
  真實載入路徑),**再**把它內部真正在跑的 `_state` 換上一個零張牌的 `CardDeck`
  (GDD 明文合法的「卡池不足 5 張時開局發不滿」邊界情形的極端值 `pool_size=0`,
  不是偽造一個規格不承認的狀態),然後呼叫該場景自己的 `_refresh_view()`,讓
  100% 正式程式碼(`HandBar.render()`、`battle_screen.gd` 的
  `hand_bar_slot_kinds()`/`availability_for()`)重繪一次。
- **S5**:🔴 **不經過完整 BattleScreen,且這是刻意的,不是偷懶**。已實測
  `battle_screen.gd`(926-930 行)的 `Synchronous by design` 註解,並用
  `grep -rn "await " src/ --include=*.gd` 全庫覆核(僅 1 個命中,且在註解裡)——
  敵方階段整批在同一次函式呼叫內同步跑完,`ENEMY_ACTING` 在現行遊戲中不會產生
  任何一個可被擷取的畫格。驅動真正的戰鬥流程**無法**讓這張截圖「發生在遊戲裡」。
  改為直接對 `res://src/ui/battle/HandBar.tscn` 呼叫
  `render([], CardDeck.HAND_SIZE_LIMIT, HandBar.Availability.LOCKED)`。
  **這張圖只證明 `HandBar` 收到 `LOCKED` 時會畫成什麼樣子,不證明現行遊戲跑得到
  這個畫面。**

兩張圖使用同一個視窗尺寸(1920×1080),`HandBar.slot_bar_rect()` 只依視窗尺寸與
`max_slots` 決定位置,因此兩張圖裡 HandBar 所在的螢幕座標完全相同 —— 這讓裁切區域
比對(灰階可區分性)是同一塊畫面座標的前後對照,不是兩個不同構圖的巧合。

## 做法

`evidence_driver.gd`:
1. 依序完成上述 S7 / S5 兩張全螢幕擷圖,各自套用
   `.claude/docs/coding-standards.md` Screenshot Evidence Rules 的機械檢查
   (尺寸、12 點抽樣相異色數 ≥ 3、主導色佔比 ≤ 80%),存到
   `production/qa/evidence/story-u011-hand-bar-{s7-empty,s5-locked}-2026-09-17.png`。
2. 用 `HandBar.slot_bar_rect()` 算出的位置,從兩張全螢幕圖各裁出同一塊區域,
   存到 `story-u011-hand-bar-{s7,s5}-crop-2026-09-17.png`。
3. 把兩張裁切圖轉灰階(HSV value 通道)做逐點比對,印出平均亮度、相異灰階數、
   平均絕對亮度差 —— **這是過濾器,不是替代人眼確認**(Rule 5)。

## 如何執行

```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . --import
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --path . prototypes/story-u011-hand-bar-evidence-2026-09-17/EvidenceDriver.tscn
```

`--path .` 指向**主專案根目錄**,不是這個子資料夾自己的 project——這支 driver
沒有自己的 `project.godot`,借用主專案當下的真實設定來驗證,不是另開一個模擬環境。
場景路徑當參數傳入,是 Godot 支援的「這次執行覆寫 `run/main_scene`」寫法,不會動到
`project.godot` 本身。

## 技術選擇的揭露(不是默默做,寫下來)

S7 那半段對真實 `BattleScreen` 實例呼叫 `battle_scene._state.attach_card_deck(...)`
與 `battle_scene._refresh_view()` —— 兩者是 `battle_screen.gd` 的私有慣例命名
(前綴底線)欄位/方法,GDScript 不強制存取控制,外部腳本仍可呼叫。這是刻意的技術
選擇:比起另建一份修改過的 `.tscn`/腳本副本(那會違反本目錄「載入正式場景本體」
的既有原則,見 `prototypes/story-001-ac-s001c-evidence-capture-2026-09-04/README.md`
同一句話),直接複用真正在跑的場景實例、只換掉它內部的 `CardDeck`,是更貼近
「證明正式程式碼會畫成什麼樣子」這個目的的做法。

## 現況(status)

**已完成(2026-09-17)**。見 `run_output.txt` 逐字輸出。四張 PNG(兩張全螢幕、
兩張裁切圖)已存到 `production/qa/evidence/`,正式證據文件(含機械檢查數字與
人眼確認記錄)在 `production/qa/evidence/story-u011-hand-bar-evidence.md`。

## Findings

見 `production/qa/evidence/story-u011-hand-bar-evidence.md` —— 本檔不重複記錄
結論數字,理由與本專案已登記的「複述會製造漂移面」規則一致。
