# 卡牌確認面板與關係三態 —— 文案鍵名表(story-020 / story-021)

> 狀態:完成(2026-11-19,`localization-lead`)。**只是鍵名表,未寫入 `strings.csv`**,由實作者加入。
> 文案依據:`design/ux/card-rework-ui-2026-11-17.md`(以下簡稱「UX」),逐字照抄,不改字。
> 已有鍵的檢查:對 `assets/data/locales/strings.csv` 逐詞 grep(好感/冷淡/敵意/騎牆/無法出牌/不退/折損/血量/視線/打不到/夥伴/可擊倒/略過/付出/各付/目前關係/第一擊/第二擊/直傷/兩人),原始輸出行見第 4 節。

## 0. 命名慣例(讀自現行 strings.csv)

- 前綴 `battle.<區>.<名>`;帶參數者尾綴 `_format`(例 `battle.card_confirm.target_format_single`、`battle.tile_info.hp_line_format`)。
- 確認面板既有前綴 `battle.card_confirm.*`;資訊卡既有前綴 `battle.tile_info.*`(攻擊原因已有 `attack_reason_*`)。
- 參數一律 `%s`(字串)/`%d`(整數),依 `printf` 位置順序;表內「參數」欄即順序。牌面數字用 `%d` 樣板由卡表帶入,符合 `design/narrative/card-face-text-14-2026-11-18.md` 第 3 行裁決。

## 1. 鍵名表

「沿用」欄:新 = 新增;沿用 = 既有鍵直接用(證據見第 4 節)。

### 1.1 三態與騎牆詞表(UX 4.1、4.5 第 3 點;單一詞表,各畫面共用)

| 鍵名 | zh_TW 文案 | 參數 | 使用處 | 沿用 |
|---|---|---|---|---|
| `battle.relation.state.pos` | 好感 | — | 021:資訊卡關係行、手牌 Z2 角落、關係圖詳情;020:確認面板「目前關係」行 | 新 |
| `battle.relation.state.none` | 冷淡 | — | 同上(含關係圖詳情區冷淡列文字,Q2) | 新 |
| `battle.relation.state.neg` | 敵意 | — | 同上 | 新 |
| `battle.relation.straddle.on` | 有效 | — | 021:麥子健資訊卡、關係圖詳情 | 新 |
| `battle.relation.straddle.off` | 失效 | — | 同上 | 新 |
| `battle.relation.straddle.line_format` | 騎牆：%s | 1=有效/失效(上兩鍵之一) | 021:資訊卡新增行;關係圖麥子健列 | 新 |
| `battle.relation.straddle.will_lose_format` | %s將失去騎牆 | 1=麥子健姓名(取 `character.name.5`) | 020:丙類確認面板預告(AC4b);營火同詞(不在本批) | 新(渲染後 = `麥子健將失去騎牆`,UX 4.4/Q3) |

### 1.2 資訊卡與手牌關係行(021)

| 鍵名 | zh_TW 文案 | 參數 | 使用處 | 沿用 |
|---|---|---|---|---|
| `battle.tile_info.relation_line_format` | 與%s：%s | 1=另一名我方單位姓名;2=三態詞(1.1 的 pos/none/neg 之一) | 021:戰場資訊卡(游標在我方單位、另有選取者時)(UX 4.2) | 新 |

### 1.3 確認面板代價區塊(020;UX 1.1、1.2)

| 鍵名 | zh_TW 文案 | 參數 | 使用處 | 沿用 |
|---|---|---|---|---|
| `battle.card_confirm.cost_hp_format` | 代價：%s 付出 %d 點血 | 1=付款人姓名;2=點數 | 020 面板,付血 | 新 |
| `battle.card_confirm.hp_change_format` | HP %d → %d | 1=前;2=後 | 020 面板,付血下一行;各付血逐人列(見下);c12 兩擊列 | 新 |
| `battle.card_confirm.cost_fray_format` | 代價：配合折損 %d | 1=折損點數 | 020 面板,折損 | 新 |
| `battle.card_confirm.fray_progress_format` | %s×%s　本場已折損 %d/%d | 1、2=兩人姓名;3=已折損;4=上限 | 020 面板,折損下一行 | 新 |
| `battle.card_confirm.cost_both_format` | 代價：兩人各付 %d 點血 | 1=點數 | 020 面板,各付血 | 新 |
| `battle.card_confirm.cost_both_row_format` | %s　HP %d → %d | 1=姓名;2=前;3=後 | 020 面板,各付血逐人一列 | 新 |
| `battle.card_confirm.relation_current_format` | 目前關係：%s | 1=三態詞 | 020 面板,雙人卡,代價行上方 | 新 |
| `battle.card_confirm.relation_none_pays_hp` | 關係冷淡，改付血 | — | 020 面板,冷淡時加一行 | 新 |
| `battle.card_confirm.fray_hint` | 本場兩人配合加成變小 | — | 020:手牌卡面 Z3 細節(UX 1.1 末段;面板不重複) | 新 |

### 1.4 付不起與確認鈕(020;UX 1.2)

| 鍵名 | zh_TW 文案 | 參數 | 使用處 | 沿用 |
|---|---|---|---|---|
| `battle.card_confirm.unaffordable_row_format` | ✕ %s　血量不足 | 1=付不起者姓名 | 020 面板,付不起者那一列 | 新(⚠ 見待決 1) |
| `battle.card_confirm.button_unplayable` | 無法出牌 | — | 020 面板,確認鈕停用時鈕面 | 新 |

### 1.5 不可打原因(020;UX 1.3 表,手牌 Z3 與面板共用同一組字串;優先序 # 即表序)

| # | 鍵名 | zh_TW 文案 | 參數 | 使用處 | 沿用 |
|---|---|---|---|---|---|
| 1 | `battle.card_reason.partner_absent` | 夥伴不在場 | — | 020 Z3/面板 | 新 |
| 2 | `battle.card_reason.fray_full` | 配合折損已滿 | — | 同上 | 新 |
| 3 | `battle.card_reason.need_ally_within_2` | 需有隊友在 2 格內 | — | 同上(c03) | 新 |
| 4 | `battle.card_reason.hp_insufficient_format` | %s血量不足 | 1=付款人姓名 | 同上 | 新 |
| 5 | `battle.card_reason.too_far_apart` | 兩人距離太遠 | — | 同上 | 新 |
| 6 | `battle.card_reason.no_enemy_in_range` | 射程內沒有敵人 | — | 同上(直傷) | 新 |
| 7 | `battle.tile_info.attack_reason_los_blocked` | 視線被擋 | — | 同上(直傷,UX 1.3 明文「與攻擊原因同一個詞」) | **沿用既有鍵**,不新增 |
| 8 | `battle.card_reason.cannot_reach_format` | %s打不到 | 1=打不到的單位姓名 | 同上(合擊) | 新 |
| 9 | `battle.card_reason.target_hp_full` | 對象血量已滿 | — | 同上(補血) | 新 |

### 1.6 直傷選敵(020;UX 2.2)

| 鍵名 | zh_TW 文案 | 參數 | 使用處 | 沿用 |
|---|---|---|---|---|
| `battle.tile_info.direct_line_format` | 直傷：%s | 1=原因文字 | 020 資訊卡原因行(游標在不合法敵人) | 新 |
| (原因 視線被擋) | 視線被擋 | — | 同上 | **沿用** `battle.tile_info.attack_reason_los_blocked` |
| (原因 目前太遠) | 目前太遠 | — | 同上 | **沿用** `battle.tile_info.attack_reason_out_of_range` |
| (原因 目前太近) | 目前太近 | — | 同上 | **沿用** `battle.tile_info.attack_reason_too_close` |
| `battle.card_confirm.can_kill` | 可擊倒 | — | 020 選敵預覽(UX 2.2 第 5 點:現行是否已有擊殺表現未驗證,**有條件才用**,見待決 2) | 新 |

傷害預覽 `HP %d → %d` 共用 1.3 的 `battle.card_confirm.hp_change_format`,不另立鍵。

### 1.7 c12 合擊兩段(020;UX 3.1、3.2)

| 鍵名 | zh_TW 文案 | 參數 | 使用處 | 沿用 |
|---|---|---|---|---|
| `battle.card_confirm.strike_first_format` | 第一擊　%s → %s　−%d　HP %d → %d | 1=出手者;2=目標;3=傷害;4=前 HP;5=後 HP | 020 面板第一列 | 新 |
| `battle.card_confirm.strike_second_format` | 第二擊　%s → %s　−%d　HP %d → %d | 同上 | 020 面板第二列 | 新 |
| `battle.card_confirm.strike_second_skipped_format` | 第二擊　%s　略過(目標已倒下) | 1=第二擊出手者 | 020 面板,第一擊會擊殺時 | 新 |
| `battle.card_confirm.cost_not_refunded` | 代價照付，不退 | — | 020 面板,略過列下一行 | 新 |
| `battle.card_confirm.strike_second_skipped_notice` | 第二擊略過 | — | 020 結算呈現:資訊卡/回合訊息列(UX 3.2,與面板預告同詞) | 新 |

註:UX 文案中的 `−` 是 U+2212(減號),`()` 為半形括號,照抄;CSV 以 UTF-8 存檔。

## 2. 三態與騎牆「每詞恰一個鍵」確認

| 詞 | 唯一鍵 | grep 現況 |
|---|---|---|
| 好感 | `battle.relation.state.pos` | 現行 CSV 沒有「純詞」鍵;見第 4 節,既有鍵只有「好感度」複合詞(另一概念,不是三態詞) |
| 冷淡 | `battle.relation.state.none` | 零命中 |
| 敵意 | `battle.relation.state.neg` | 零命中 |
| 騎牆有效 / 失效 | `battle.relation.straddle.on` / `.off`,組句只用 `battle.relation.straddle.line_format` | 零命中 |

- 面板、資訊卡、手牌、關係圖全部引用上列鍵;**不得**在任何畫面另寫 `好感`/`冷淡`/`敵意` 字面中文,也**不得**把詞直接寫進格式字串(例如把 `冷淡` 寫死進 `relation_line_format`)—— 格式鍵的 `%s` 一律由上列詞鍵填入。
- `battle.card_confirm.relation_none_pays_hp`(`關係冷淡，改付血`)與 `battle.card_confirm.fray_hint` 內含「冷淡」字面,屬 UX 指定的整句固定文案,不是三態詞標籤;AC-12 的 grep 驗「三詞各一個鍵」時,這兩句會讓 `冷淡` 字串多命中一行,**驗收指令應以鍵名為準,不以字串為準**(此為待決 3 的風險說明)。
- 好感/冷淡/敵意三詞在 UX 4.2 手牌卡角落「徽記 + 2 字」與資訊卡「與%s：好感」共用同一組鍵,無第二份。

## 3. 待決(UX 缺漏或矛盾,不自擬)

1. **付不起列的格式與「原因 #4」不同形**:UX 1.2 範例 `✕ 董振豪　血量不足`(姓名後全形空格,`✕ ` 前綴)與 1.3 #4 `%s血量不足`(姓名緊接)是兩種字串。UX 1.3 又寫「手牌與面板共用同一組字串」。本表為忠於兩處逐字,立了兩個鍵(`unaffordable_row_format` 與 `hp_insufficient_format`)。若要共用單一鍵,需 UX 擇一(`✕ ` 前綴 + #4 字串會變成 `✕ 董振豪血量不足`,少一個空格)。**請 ux-designer 裁定是否接受兩鍵。**
2. **`可擊倒`的有無**:UX 2.2 第 5 點寫「擊殺時的呈現是否已有表現:未驗證;沒有的話本檔要求至少文字 `可擊倒`」。鍵先備好(`battle.card_confirm.can_kill`),但用不用取決於實作者查現行 `hp_preview` 是否已有擊殺表現(AC-5/AC-6 未列此項)。
3. **AC-12 驗證指令**:UX AC-12 要求「好感/冷淡/敵意/騎牆各只有一個 strings.csv 鍵」,但 `關係冷淡，改付血`、`配合折損`、`冷淡` 等整句固定文案內含同字;若用字串 grep 驗證會多命中。驗證須改以鍵名引用掃描(`coding-standards.md`:驗證指令不得自我命中)。請 qa-lead/實作者在寫該測試時定驗法。
4. **手牌 Z3「該對兩人姓名」那一行**(UX 4.2)沒有給具體格式。可沿用 1.3 的 `%s×%s`(但該字串目前只存在於 `fray_progress_format` 內,不是獨立鍵)。**未自擬**:請 ux-designer 指定格式後再加鍵。
5. **手牌 Z2 卡面「徽記 + 2 字」**(UX 4.2)直接取 1.1 三態鍵,無額外格式,視為無缺;若美術要加前綴符號,屬圖示不是文案。
6. **`確認` 鈕面字樣**:UX 1.2 說停用時 `無法出牌` 取代 `確認`,但現行 CSV 沒有獨立 `確認` 鈕面鍵(只有 `battle.hud.hint.confirm.*` 的操作提示字串「確認 Enter」等)。面板確認鈕現行字是否為獨立鍵或寫死,**未查實作碼,未驗證**。若面板確認鈕目前是字面中文,實作者需另立鍵(建議 `battle.card_confirm.button_confirm`,文案 `確認`),屬 020 範圍內的順手補;此鍵**不計入**本表鍵數。
7. **`麥子健將失去騎牆` 的姓名處理**:UX 把它當整句固定文案。本表立為 `%s將失去騎牆` 並由 `character.name.5` 帶入(避免第二份姓名字面,渲染結果逐字相同)。若管理者/ux 要求固定整句鍵,改成無參數鍵即可,不影響其他列。

## 4. 沿用查核:grep 原始輸出行

指令:`grep -n "好感\|冷淡\|敵意\|騎牆\|無法出牌\|不退\|折損\|血量\|視線\|打不到\|夥伴\|可擊倒\|略過\|付出\|各付\|目前關係" assets/data/locales/strings.csv`(輸出節錄,與本表相關者)

```
8:battle.hud.affinity_preview_format,好感度 %+d→%+d
9:battle.hud.affinity_current_format,好感度 %+d
10:battle.hud.damage_preview_format,打擊 %d　血量 %d→%d
47:battle.card_confirm.strength_label_format,好感度：%s
56:battle.attack_confirm.target_hp_format,目標血量：%d → %d
92:shell.settings.hide_affinity_toggle,隱藏好感度顯示
181:battle.tile_info.attack_reason_los_blocked,視線被擋
247:battle.legend.attack_los_blocked.desc,射程內，但視線被擋
167:shell.title.skip_tutorial,略過教學
124:support.sc01.line11,...夥伴吧...(劇情台詞,與本表無關)
```

另外直接沿用的鍵(`grep -n "^battle.tile_info.attack_reason"`):

```
179:battle.tile_info.attack_reason_out_of_range,目前太遠
180:battle.tile_info.attack_reason_too_close,目前太近
181:battle.tile_info.attack_reason_los_blocked,視線被擋
```

結論:
- 「好感度」(數值概念)出現在 8/9/31/47/52/92 行,**與三態詞「好感」不同概念,不可沿用**,也不可把三態詞改併入這些鍵。
- `冷淡`、`敵意`、`騎牆`、`無法出牌`、`不退`、`折損`、`打不到`、`可擊倒`、`付出`、`各付`、`目前關係`、`第一擊`、`第二擊`、`直傷`:零命中,全新增。
- 沿用既有鍵共 3 個:`battle.tile_info.attack_reason_los_blocked`、`..._out_of_range`、`..._too_close`。
- 姓名來源:`character.name.1`~`.5`(第 109~113 行)已存在,面板/資訊卡姓名由此帶入,不新增姓名鍵。
- `%s`/`%d` 樣板風格與既有一致(`battle.card_confirm.target_format_single` 等)。

## 5. 鍵數統計

- 新增鍵:**34**(1.1 共 7;1.2 共 1;1.3 共 9;1.4 共 2;1.5 共 8(#7 沿用);1.6 共 2(`direct_line_format`、`can_kill`);1.7 共 5)。
- 沿用既有鍵:3 個(`attack_reason_los_blocked`、`attack_reason_out_of_range`、`attack_reason_too_close`)。
- 待決:7 項(其中 1、2、4、6 影響實作者動工前的決定;3、5、7 屬提醒)。

## 補登(2026-11-19 收工,協調者;管理者同日核准「逐項核對後改」)

以 `git diff e4423d9 c1984ab` 的 strings.csv 新增列逐鍵比對本表,已提交但本表未列者 2 個:

| 鍵 | zh_TW | 來源 |
|---|---|---|
| `battle.card_confirm.strike_single_format` | `%s → %s　−%d　HP %d → %d` | story-020c 單擊直傷列(實作者新增,本表原無) |
| `battle.card_hand.pair_names_format` | `%s×%s` | ux 裁定 `card-rework-loc-keys-ux-ruling-2026-11-19.md` 待決 4,story-021 加入 |

⚠️ story-020d(worktree `agent-af3bfd0e6f621b7cc`,未合入)另加 7 列(含 `battle.relation.straddle.will_lose_format`)、ux 空白判定 `card-confirm-panel-ux-gaps-2026-11-19.md` 提議 3 鍵 —— 合入時再補登。
