# 各關開場目標一行字

| 欄位 | 內容 |
|---|---|
| 建立日期 | 2026-11-12 |
| 作者 | `level-designer` |
| 依據 | 管理者 2026-11-11 裁決「開場目標:要,教學與正式關都加(推薦)」;供 `production/epics/tactical-combat/story-046-objective-and-legend-entry.md`(AC1/AC3 前置)取用 |
| 狀態 | 初稿,待 `game-designer`/管理者過目;未經審查 |

## 一、查證依據(逐條,附來源)

1. **勝敗規則只有一套、與關卡無關**:`src/gameplay/battle/battle_state.gd` 的 `outcome()`(函式上方文件註解 + 本體)——任一我方單位死亡 → DEFEAT(先判);否則任一敵方單位存活 → ONGOING;否則 VICTORY。查證方式:讀該函式全文。**函式內沒有任何關卡參數**,故正式 5 場與教學 4 場的勝利條件文字相同。
2. **關卡清單**(`assets/data/levels/campaign_sequence.txt` 5 列;`tutorial_sequence.txt` 4 列)。測試夾具 `test_fixture_*` 不計。場名取自 `design/quick-specs/mvp-five-levels-skeleton.md`(第 1~5 場:《迷霧岔口》《追痕》《正面交鋒》《舊地盤邊緣》《據點決戰》)。
3. 教學各場「教什麼」取自 `assets/data/units/tut01~04_roster.txt` 檔頭「教什麼」註解與 `design/quick-specs/tutorial-level.md` 第 2、3 節;本檔不自訂規則。
4. 在地化命名風格:`strings.csv` 既有 `battle.hud.*`、`battle.menu.*`、`battle.card_confirm.*`,格式為「`battle.<區塊>.<名稱>`」,多字名用底線、格式字串以 `_format` 結尾。(只 grep 前 40 列,**未看全檔**,未確認 `battle.objective.*` 是否已被占用。)

## 二、文字(皆不含數字,敵人數量/地圖大小/卡牌與營火改版不影響)

「字數」= 全形字元含標點,我逐字數的(目標 ≤ 16)。

### A. 正式關(第 1~5 場共用一行)

| 鍵名建議 | 文字 | 字數 |
|---|---|---|
| `battle.objective.line` | 擊倒所有敵人，我方無人倒下 | 13 |

- 寫法理由:同時講出「怎樣贏」與「唯一的輸法」,玩家不必等到戰敗才知道「任一人倒下即敗」(此規則與常見戰棋「全滅才輸」不同,見 `tutorial-level.md` P3)。「所有」不綁敵數,敵方增減或換圖仍成立。
- 若 story-046 AC3 另有「規則一行」(戰敗/勝利結果文字),可與本行同源:**建議 AC3 另開鍵** `battle.result.rule_victory`、`battle.result.rule_defeat`,文字待設計網域另寫(本單只被要求開場目標,**未擬**,以免重複造規則描述)。
- 是否需要每場獨立鍵(例如第 5 場寫不同話)?**目前規則上沒有差異,不建議**;日後若某場加入非全滅條件(護送/限時等,`outcome()` 需先改),再各開 `battle.objective.m<N>`。⚠️ 這是推測,未向 `game-designer` 確認是否有任何關卡預定改勝利條件。

### B. 教學關(第 1~4 場)

開場目標沿用 A 行(`battle.objective.line`),**另加一行「這關學什麼」**,在目標行之下顯示。

| 場 | 場面(來源) | 鍵名建議 | 「這關學什麼」 | 字數 |
|---|---|---|---|---|
| 教學 1 | S1 空地:P1 選單位→移動→確認 | `battle.objective.tut01_learn` | 選取角色，看移動範圍再走過去 | 14 |
| 教學 2 | S2 一對一:P2 攻擊、射程、傷害預覽 | `battle.objective.tut02_learn` | 靠近敵人，看射程與傷害預覽再攻擊 | 16 |
| 教學 3 | S3 看見威脅:P3/P4 敵人也有移動+射程 | `battle.objective.tut03_learn` | 選中敵人看威脅範圍，小心踏入 | 14 |
| 教學 4 | S4 小組:P5 站位改傷害預覽(只教「看得見」) | `battle.objective.tut04_learn` | 兩人並肩或拆開，看傷害預覽變化 | 15 |

另建議教學關**目標行**可共用 A 行,不另開教學專用鍵。

## 三、設計理由與風險(未查證項明標)

- **教學 4 的污染風險**:`tutorial-level.md` 第 4 節與 2026-10-29 加註(Q2 已決)要求教學**不命名「好感度/關係」、不刻意安排因果**。上列文字只提「並肩/拆開」與「傷害預覽變化」,**未出現好感度、關係、加成**;但「並肩或拆開」是否仍算過度提示、會否削弱第 1 場探針:**未驗證**(沿用該檔 Q2 的未驗證狀態),如管理者要更保守,可改成只剩「看傷害預覽變化」(8 字)。
- **教學 3**:roster 註解寫明「原地等/搶先踏入都安全」,故不寫「別踏入」這種禁令,只寫「小心踏入」。
- **教學 2**:文字不寫「敵人會還手」,因 roster 註解自承是否為反擊「未驗證」。
- **教學 1**:該關有 1 名遠方敵人(roster 註解);目標行「擊倒所有敵人」在此成立,且與「走向遠處敵人」相呼應。
- **「敵人」一詞**:戰鬥系統名冊用 `ENEMY` 派系;遊戲內對外名稱是否為「敵人」/「敵兵」:**未查證**(敘事文件未讀),暫用「敵人」,與 `tutorial-level.md` 一致。
- **「我方」一詞**:`strings.csv` 現有 `battle.hud.faction_player` 為「我方行動」,風格一致;但 `design/narrative` 用「夥伴」處(SC-01),我方未採,理由:HUD 既有用語優先。**未與 narrative-director 確認。**
- **未讀**:`vs01~vs05_roster.txt` 全文(只計得每場敵人 5 名,僅供自己判斷「不要寫死數字」);`vertical-slice-level-01.md`;story-046 以外的 story。
- **鍵名與 CSV 欄位**:未開啟 `strings.csv` 看欄位結構(第一欄鍵、第二欄中文,由 grep 輸出推定),實作時請照該檔既有欄位;資料檔勿用 `.csv` 以外副檔名誤放——本檔只是文字提案,不寫入 CSV(CSV 屬 story-046 Affected Files)。
