# 手把按鈕序號 → 實體按鍵對照探針(2026-10-16)

**這不是試作,是一支一次性的證據探針。** 它回答一個明文登記的未決項。

## 它回答什麼

`design/quick-specs/battle-hud-prediction-marker.md` 第 7 節第 6 項把
「手把 `battle_guess_cycle` 建議的按鈕序號 **3** 對應哪顆實體按鈕」列為未決,
理由是 `docs/engine-reference/godot/VERSION.md` 把 Godot 4.7 的輸入裝置變動
列為 post-cutoff 知識缺口,而 `docs/engine-reference/godot/modules/input.md`
停在 4.6(該檔頭自述 `Engine: Godot 4.6`)。

**查不到文件,所以直接問引擎。**

## 🔴 它【不需要】實體手把

本探針讀的是**引擎自己的列舉常數**,不是任何裝置送來的輸入事件。
因此它在 headless、無手把的機器上成立。

## 證據等級:(A)

依 `.claude/docs/technical-preferences.md`「(A) 的精確定義」——
引擎執行了專案釘死的那一版,而不是重新實作一份規則。
**執行的檔案**:`prototypes/joy-button-index-probe-2026-10-16/probe_joy_buttons.gd`
**原始輸出**:`prototypes/joy-button-index-probe-2026-10-16/run_output.txt`

## 結果(逐字)

```
ENGINE = { "major": 4, "minor": 7, "patch": 1, "status": "stable", "build": "official",
           "hash": "a13da4feb8d8aefc283c3763d33a2f170a18d541", "string": "4.7.1-stable (official)" }
JOY_BUTTON_A              = 0
JOY_BUTTON_B              = 1
JOY_BUTTON_X              = 2
JOY_BUTTON_Y              = 3
JOY_BUTTON_BACK           = 4
JOY_BUTTON_START          = 6
JOY_BUTTON_LEFT_SHOULDER  = 9
JOY_BUTTON_RIGHT_SHOULDER = 10
JOY_BUTTON_LEFT_STICK     = 7
JOY_BUTTON_RIGHT_STICK    = 8
JOY_BUTTON_MAX            = 128
```

## 對應到本專案既有綁定(`project.godot` 的 `[input]` 節)

| 動作 | pad 序號 | 實體按鍵 |
|---|---|---|
| `battle_confirm` | 0 | A |
| `battle_cancel` | 1 | B |
| `battle_open_hand` | 2 | X |
| `battle_end_unit_turn` | 4 | **BACK**(View/Select) |
| `battle_menu` | 6 | START |
| `battle_prev_target` | 9 | LEFT_SHOULDER |
| `battle_next_target` | 10 | RIGHT_SHOULDER |

## 結論

1. ✅ **序號 3 = `JOY_BUTTON_Y`。** 規格建議的 `battle_guess_cycle` 用序號 3 成立,
   它是一顆正規的面鍵,不是系統鍵。**第 7 節第 6 項可結案。**
2. ✅ **肩鍵衝突屬實** —— 9/10 確實是 LEFT/RIGHT_SHOULDER,已被
   `battle_prev_target` / `battle_next_target` 佔用。
3. 📌 **順帶登記、不屬本次範圍**:`battle_end_unit_turn` 綁在序號 4,
   而序號 4 是 **BACK**(通常是 View/Select 那顆小鍵)。
   把「結束這個單位的行動」這種高頻操作綁在系統鍵上,人體工學上可疑。
   🔴 **本探針只登記這個事實,不下判斷** —— 要不要改是 UX/輸入設計的裁決,
   不是一支證據探針的職權。

## 它證明不了什麼

- **不證明任何實體手把上那顆鍵的位置或標籤。** 不同廠牌的手把對同一個
  `JoyButton` 列舉值會印不同的字(例如 PlayStation 的 △ 與 Xbox 的 Y)。
  本探針只確定**引擎側的序號對應**,不確定玩家手上那顆鍵長什麼樣。
- **不證明 `JOY_BUTTON_*` 在未來版本不會變。** 它只量了 4.7.1-stable。
