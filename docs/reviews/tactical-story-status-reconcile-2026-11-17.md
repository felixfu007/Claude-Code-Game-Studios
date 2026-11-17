# 戰棋工作單狀態對帳(2026-11-17)

> 撰寫:`producer`(只讀對帳;本檔是唯一寫入的檔案,**未修改任何既有檔**)
> 範圍:`production/epics/tactical-combat/story-*.md` 檔頭 `Status` ↔ `story-index.md` ↔ git 提交
> 用途:協調者呈管理者核准後,照第四節逐字套用。**本檔本身不構成核准。**

## 一、方法(可重跑)

| 來源 | 指令 / 讀法 |
|---|---|
| 檔頭 | 每檔 `grep -m1 -n 'Status'` + 讀第 3~12 行的加註 |
| 總表 | 讀 `story-index.md` 第 117~178 行(Story 清單表) |
| git | `git log --oneline --all -i --since=2026-10-28`,再 grep `story-0NN`;合併提交(`story-041/042/043`)與帶 `(story-046 AC2)` 的提交都有命中 |
| 提交日期 | `git show -s --format="%h %ad" --date=short <hash>`(第三節列的日期皆出自此,已驗) |
| 還缺哪條 AC | 各檔 `grep -n "AC[0-9]+"` 再篩「像素層/補拍/開窗/人眼」;對照 `production/session-state/active.md` 第 76~130 行(第一百零一、一百零二批) |

**範圍**:030~058 全部逐張核對;001~029 只抽查到 021 一筆落差(見下),**001~020、022~029 未逐張與 git 核對(未驗證)**。

**狀態用語**:沿用本 epic 022~029 已在用的寫法 —— `✅ Done`(全部 AC 已滿足)、
`✅ Done-pending-visual`(程式與測試已提交,只剩像素層/人眼 AC)。原狀態一律以「(原狀態:…)」保留,
與 023~029 的既有慣例一致,符合本專案「原句不刪」紀律。

⚠️ **AC 勾選框不作判準。** 本 epic 慣例是交付時不補勾(story-021 檔頭加註明文「本加註不補勾」),
所以「`[ ]` 未勾」不等於沒做。本檔判「還缺什麼」只依兩件事:①工單 AC 自己寫明是「像素層/補拍/人眼」;
②交接檔沒有記載它已被拍到並審過。

## 二、有落差的列(22 張)

| # | 檔頭 Status 原文(節錄) | 總表該列原文(節錄) | git 證據(原始輸出行) | 判定的正確狀態 | 還缺哪條 AC |
|---|---|---|---|---|---|
| 021 | `Ready(2026-10-28)`(下有 11-05、11-06 加註「以此為準視為完成」) | `Ready(2026-10-28)(依檔頭;2026-10-30 補列)` | `2ab702a feat(battle): story-021 自動對戰迴圈接上好感度加成` | ✅ Done | 無(加註寫 AC4 依本張但書處理) |
| 033 | `✅ Done(2026-10-30,提交 e7751fc;…)` | `✅ Done(依提交 e7751fc,檔頭待改;檔頭現寫 Ready(2026-10-30))` | (grep `story-033` 未命中提交標題;檔頭與總表皆引 `e7751fc`,`git show` 存在、日期 2026-10-30) | ✅ Done —— **只有總表過期**(「檔頭待改」已改了) | 無 |
| 036 | `Ready(查證無擋路事項;…)`(下有 11-10 加註「已完成」) | `✅ Done(289c837;…檔頭 Status 行仍寫 Ready…)` | `289c837 feat(data): 第 4 場 E3 改站 (11,4)(story-036);…` | ✅ Done | 無 |
| 037 | `Blocked(未決點 1、2、3 …)`(下有兩則 11-11 加註:改 Ready、程式完成) | `✅ 程式完成(34c2f2d;…AC-5~7 待在家驗收;檔頭 Status 行仍寫 Blocked…)` | `34c2f2d feat(battle): 棋子正式圖接線(…)(story-037)` | ✅ Done-pending-visual | AC-5~7(在家驗收;正式圖 `86fde93` 已入庫,是否已驗**未驗證**) |
| 038 | `Ready(2026-11-11 協調者起草)`(下有 11-11 加註「已完成」) | `✅ Done(f0884ac;檔頭 Status 行仍寫 Ready…)` | `f0884ac fix(data): 資料檔解析防呆改為發行版也有效 …(story-038)` | ✅ Done | 無 |
| 039 | `Ready(2026-11-12)` | `✅ Done(依提交 487b6e0,檔頭待改…)` | `487b6e0 feat(battle): 資訊卡顯示正式姓名 + 棋子標姓名首字/敵兵編號(story-039)` | ✅ Done | 無(工單無像素層 AC;grep 零命中) |
| 040 | `Ready(2026-11-12)—— …須在 story-039 提交後才開工` | `✅ Done(依提交 c28bde9,檔頭待改…)` | `c28bde9 feat(battle): 資訊卡顯示「攻擊：原因」…(story-040)` | ✅ Done-pending-visual | AC6 像素層(交接檔 11-12:「040 其餘原因文字」待開窗) |
| 041 | `Ready(2026-11-12)` | `✅ Done(依提交 74fbce7,檔頭待改…)` | `74fbce7 feat(battle): 血量數字與首字分層、…(story-041/042/043)` | ✅ Done-pending-visual | AC6 像素層(交接檔 11-12:「041 血量 8px 可讀性」待開窗) |
| 042 | `Ready(2026-11-12)` | `✅ Done(依提交 74fbce7,檔頭待改…)` | 同上 `74fbce7` | ✅ Done-pending-visual | AC5 像素層(**是否已拍未驗證**) |
| 044 | `Ready(2026-11-12)—— 🔴 前置:art-director 須先交付…` | `✅ Done(依提交 7c0333e,檔頭待改…)` | `7c0333e feat(battle): 高亮層級重做 —— …(story-044)` | ✅ Done-pending-visual | AC8(11-16 午休 ux 判「有條件過」;工單自己建議 48 格後再拍) |
| 045 | `Ready(2026-11-12)—— 🔴 含一項須先裁決的設計缺口…` | `✅ Done(依提交 278fb77,檔頭待改…)` | `278fb77 feat(battle): 提示列依狀態與裝置只顯示相關按鍵(story-045)` | ✅ Done-pending-visual | AC7(11-16 ux 判「過」,但那批驅動用合成夾具;**是否涵蓋 AC7 要求的三態 × 兩解析度,未驗證**) |
| 046 | `Ready(2026-11-12)—— 🔴 前置:須有「一行勝利條件文字」…` | `🟡 部分完成(依提交 5c5602c:AC1/3/4;AC2 選單入口未提交…)` | `5c5602c …(story-046 AC1/3/4)`;**`bf05f56 feat(menu): 戰鬥選單新增「目標」「圖例」入口(story-046 AC2)`** | ✅ Done-pending-visual —— **總表說 AC2 未提交,錯;`bf05f56`(11-13)已提交** | AC6 像素層(今日午休驅動含「046 選單五列」) |
| 047 | `Ready(2026-11-12)—— 🔴 前置:story-044 …定稿、story-046 …落地` | `📋 Ready(2026-11-12)` | `f877533 feat(battle): 圖例面板(…)(story-047)` | ✅ Done-pending-visual | AC6 像素層(今日午休驅動含「047 AC6」) |
| 048 | `Ready(2026-11-12)—— 🔴 前置:art-director 的「面板語言統一」…`(下有 11-16 加註:AC1 已提交、AC2 擱置) | `🟡 部分完成(依提交 1c07b32:AC1;AC2 起未提交…)` | `1c07b32 feat(battle): 資訊卡改不透明底 + 內外雙框 + 比例內距(story-048 AC1)` | ✅ Done(AC1);AC2 依管理者 11-16 裁決擱置 —— **總表「部分完成、未提交」會讓人以為還要做** | 無待補(AC2 擱置,非待辦) |
| 050 | `Ready(2026-11-13 草擬;待管理者看過後轉 Ready 亦可…)` | `✅ Done(49ff7ca,2026-11-13)` | `49ff7ca feat(board): 地形顯示名「倒木」改為「密林」(story-050)` | ✅ Done | 無(工單無像素層 AC;grep 零命中) |
| 051 | `Ready(2026-11-13,三題皆已定,無待決)` | `📋 Ready(2026-11-13)` | `0bd5295 feat(battle): 敵方型別資料欄 + 依型別命名編號 …(story-051)` | ✅ Done-pending-visual | AC7 像素層(11-16 午休用的是夾具 → 顯示「敵兵 N」退回值;須真 vs01) |
| 052 | `Ready(2026-11-13)—— ✅ GDD 已由協調者同步…` | `📋 Ready(2026-11-13)` | `8b8e339 feat(battle): 被擋章只畫在敵兵格,空格不畫;…(story-052)` | ✅ Done-pending-visual | AC7 像素層(vs01 丙選取;11-16 未拍到) |
| 053 | `Ready(2026-11-13,依 ux 定稿與命名/段落序裁決更新)—— …` | `📋 Ready(文案待 ux 覆核)` | `3759352 feat(battle): 滑鼠「結束角色行動」按鈕;…(story-053)` | ✅ Done-pending-visual | AC9 像素層:11-16 ux「四項目測通過」;**「真實高亮壓框下的變淡」仍待今日午休補拍**(交接檔第 82 行「053 真壓框」) |
| 054 | `Ready(2026-11-13,art 補遺已到)—— ⚠️ 兩項小待決不擋開工…` | `⛔ Blocked(待 art 補遺併入)` | `0582b98 feat(battle): 行動狀態圖示 鞋=已移動、劍=已攻擊 …(story-054)` | ✅ Done-pending-visual —— **總表寫 Blocked,方向最遠** | AC8 像素層 + **盲測(管理者本人受測)**;交接檔記「AC8 驅動未做」 |
| 055 | `🔴 Blocked(2026-11-13)—— 步驟 1 量測可先做;…` | `⛔ Blocked(待開窗量測 + 修法選擇)` | `1a5e886 fix(battle): 傷害預覽血量字被切 —— …(story-055)` | ✅ Done-pending-visual —— **檔頭與總表兩邊都寫 Blocked** | AC2:協調者 11-16 開窗只驗到 `30→15` 一個字串、一個解析度;AC2 要求 5 個字串 + 最長情境 × 960/1080 兩解析度 —— **其餘未驗證** |
| 056 | `Ready(2026-11-13)—— 🔴 「下一步」行用字須 game-designer 定稿…` | `📋 Ready(2026-11-13;「下一步」行用字待 game-designer 定稿)` | `034ae30 feat(campaign): 戰役戰敗改為直接重打同一場,不回標題(story-056)` | ✅ Done-pending-visual | AC7 像素層(戰敗畫面,Category B;11-16 夾具非戰役 → 未拍到) |
| 057 | `Ready(2026-11-16,管理者已裁決方案)—— 🔴 排序前置見最後一節(047 之後)` | `📋 Ready` | `7cc0d1f feat(battle): 我方棋子首字加深色底 #0E0F14 α0.72(story-057)` | ✅ Done-pending-visual | AC7 Check 5 **管理者本人**看圖,五位角色逐張。協調者 11-16 開窗看過、管理者裁決「游標格洗淡可接受」;**管理者是否已逐張看過五位,未驗證** |

## 三、無落差計數

- **030~058 範圍內無落差:8 張** —— 030(❌ Closed,兩邊一致)、031、032、034(兩邊 Done;`ace389b` 2026-10-30 存在)、035、043(兩邊皆 Done(AC1)+ 延後項)、049(兩邊 Ready,無提交)、058(兩邊 Ready)。
- 📌 **058 實際狀態是「進行中」**(交接檔第 79 行:godot-gdscript-specialist 主目錄施工中,尚未提交)。依本專案慣例 Ready 期間施工不改欄,**本檔不提改法**,收工時再對。
- 📌 **049 前置已到齊**(045 已提交;art/ux 兩份 2026-11-17 規格已交,見交接檔第 80~81 行),但仍屬 Ready,不算落差。

### 結構性觀察(不屬單列落差,供協調者決定要不要另處理)

1. **總表 001~017、023~029 這幾列沒有狀態欄位內容**(只有範圍與依賴),所以「總表與檔頭一致」對它們是空的 —— 不是對過了一致,是沒得對。
2. **總表第 4 行自稱「EPIC.md 的『## Stories』表才是正式狀態欄」,但 `grep -n -E "05[0-8]|04[0-9]|03[0-9]|021" EPIC.md` 只命中第 392 行一行程式引文** —— 030 以後的工作單在 EPIC.md 沒有任何列。**正式狀態欄的宣稱目前指向一張不含這些工作單的表。**(EPIC.md 其餘段落未讀,未驗證是否以其他編號格式列出。)
3. **落差的成因是同一個形狀**:提交程式時沒同步改檔頭,事後由總表以「依提交 X,檔頭待改」補記 —— 補記本身又過期(033 檔頭已改、總表仍寫待改;046 AC2 已提交、總表仍寫未提交)。總表第 185~201 行的「附帶建議 2」檢查腳本**只比對「測試檔存在 + 狀態欄不含 `Complete`」**,而本 epic 實際用的字是 `Done` —— **照現行腳本跑,030 以後每一張已完成的都會被報 MISMATCH,包括檔頭已正確的**,所以它抓不出本表這些落差(推論,未實跑)。

## 四、建議的逐字 diff

**套用原則**:只換每檔第一個 `> **Status**:` 行;原文完整保留在「(原狀態:…)」裡;檔頭下方既有加註一律不動。
**總表**只換第 117~178 行表格中對應列的「一句話範圍」欄內狀態那一段。
⚠️ 四份檔頭(036/037/038/048)下方已有「管理者核准加註」說明狀態;本 diff 是把加註的結論提到 Status 行,**不是新裁決** —— 但改既有文件仍須管理者核准(`CLAUDE.md` 2026-10-12 裁決:文件側必須先問)。

### 4-1 工作單檔頭(21 檔)

```diff
--- story-021-battle-loop-phi-provider.md
-> **Status**: Ready(2026-10-28)
+> **Status**: ✅ Done(2026-10-28,提交 `2ab702a`;見下方 11-05/11-06 加註)(原狀態:Ready(2026-10-28))

--- story-036-vs03-vs04-roster-adjust.md
-> **Status**: Ready(查證無擋路事項;有 3 項與裁定書假設不符或需注意,見「查證結果」)
+> **Status**: ✅ Done(2026-11-10,提交 `289c837`;見下方加註)(原狀態:Ready(查證無擋路事項;有 3 項與裁定書假設不符或需注意,見「查證結果」))

--- story-037-piece-sprites.md
-> **Status**: Blocked(未決點 1、2、3 —— 詳見最後一節;**程式部分可先用佔位圖做完,不必等素材,但未決點 1 會決定敵方那一側的範圍**)
+> **Status**: ✅ Done-pending-visual(2026-11-11,提交 `34c2f2d`;AC-5~7 待在家驗收,見下方加註)(原狀態:Blocked(未決點 1、2、3 —— 詳見最後一節;**程式部分可先用佔位圖做完,不必等素材,但未決點 1 會決定敵方那一側的範圍**))

--- story-038-release-safe-data-parsing.md
-> **Status**: Ready(2026-11-11 協調者起草)
+> **Status**: ✅ Done(2026-11-11,提交 `f0884ac`)(原狀態:Ready(2026-11-11 協調者起草))

--- story-039-unit-name-and-piece-initials.md
-> **Status**: Ready(2026-11-12)
+> **Status**: ✅ Done(2026-11-12,提交 `487b6e0`)(原狀態:Ready(2026-11-12))

--- story-040-attack-blocked-reason-line.md
-> **Status**: Ready(2026-11-12)—— 2026-11-12 依 lead-programmer 審查改寫 AC。🔴 須在 story-039 提交後才開工(同一個檔)
+> **Status**: ✅ Done-pending-visual(2026-11-12,提交 `c28bde9`;AC6 像素層待開窗)(原狀態:Ready(2026-11-12)—— 2026-11-12 依 lead-programmer 審查改寫 AC。🔴 須在 story-039 提交後才開工(同一個檔))

--- story-041-hp-text-vs-piece-label-overlap.md
-> **Status**: Ready(2026-11-12)
+> **Status**: ✅ Done-pending-visual(2026-11-12,提交 `74fbce7`;AC6 像素層待補拍)(原狀態:Ready(2026-11-12))

--- story-042-tile-info-line-of-sight-wording.md
-> **Status**: Ready(2026-11-12)
+> **Status**: ✅ Done-pending-visual(2026-11-12,提交 `74fbce7`;AC5 像素層待補拍)(原狀態:Ready(2026-11-12))

--- story-044-highlight-hierarchy-rework.md
-> **Status**: Ready(2026-11-12)—— 🔴 **前置:art-director 須先交付「高亮層級規格」**(見「派工前須先決定」;沒有規格不得寫碼,數值不得由實作者自創)
+> **Status**: ✅ Done-pending-visual(2026-11-13,提交 `7c0333e`;AC8 像素層 2026-11-16 ux 判有條件過,建議 48 格後重拍)(原狀態:Ready(2026-11-12)—— 🔴 **前置:art-director 須先交付「高亮層級規格」**(見「派工前須先決定」;沒有規格不得寫碼,數值不得由實作者自創))

--- story-045-contextual-controls-hint.md
-> **Status**: Ready(2026-11-12)—— 🔴 含一項須先裁決的設計缺口(見「派工前須先決定」第 1 點)
+> **Status**: ✅ Done-pending-visual(2026-11-13,提交 `278fb77`;AC7 像素層待補拍三態 × 兩解析度)(原狀態:Ready(2026-11-12)—— 🔴 含一項須先裁決的設計缺口(見「派工前須先決定」第 1 點))

--- story-046-objective-and-legend-entry.md
-> **Status**: Ready(2026-11-12)—— 🔴 前置:須有「一行勝利條件文字」(設計網域,`game-designer` 提供;實作者不得自擬規則描述)
+> **Status**: ✅ Done-pending-visual(2026-11-13,提交 `5c5602c` AC1/3/4 + `bf05f56` AC2;AC6 像素層待補拍)(原狀態:Ready(2026-11-12)—— 🔴 前置:須有「一行勝利條件文字」(設計網域,`game-designer` 提供;實作者不得自擬規則描述))

--- story-047-legend-panel.md
-> **Status**: Ready(2026-11-12)—— 🔴 前置:story-044(T5 高亮層級)定稿、story-046(選單入口)落地
+> **Status**: ✅ Done-pending-visual(2026-11-16,提交 `f877533`;AC6 像素層待補拍)(原狀態:Ready(2026-11-12)—— 🔴 前置:story-044(T5 高亮層級)定稿、story-046(選單入口)落地)

--- story-048-tile-info-panel-frame-and-placement.md
-> **Status**: Ready(2026-11-12)—— 🔴 前置:art-director 的「面板語言統一」決定(框/底色規格)
+> **Status**: ✅ Done(AC1,2026-11-12,提交 `1c07b32`);AC2 依管理者 2026-11-16 裁決擱置,見下方加註(原狀態:Ready(2026-11-12)—— 🔴 前置:art-director 的「面板語言統一」決定(框/底色規格))

--- story-050-terrain-rename-fallen-log-to-dense-forest.md
-> **Status**: Ready(2026-11-13 草擬;待管理者看過後轉 Ready 亦可,無待決題)
+> **Status**: ✅ Done(2026-11-13,提交 `49ff7ca`)(原狀態:Ready(2026-11-13 草擬;待管理者看過後轉 Ready 亦可,無待決題))

--- story-051-enemy-kind-data-and-per-kind-names.md
-> **Status**: Ready(2026-11-13,三題皆已定,無待決)
+> **Status**: ✅ Done-pending-visual(2026-11-16,提交 `0bd5295`;AC7 像素層待用真 vs01 補拍)(原狀態:Ready(2026-11-13,三題皆已定,無待決))

--- story-052-blocked-stamp-only-on-enemy-cells.md
-> **Status**: Ready(2026-11-13)—— ✅ **GDD 已由協調者同步**(`tactical-combat-system.md` 第 105/557/563/565 行共 4 行;下節建議文字保留作決策紀錄,以 GDD 現文為準)
+> **Status**: ✅ Done-pending-visual(2026-11-13,提交 `8b8e339`;AC7 像素層待補拍)(原狀態:Ready(2026-11-13)—— ✅ **GDD 已由協調者同步**(`tactical-combat-system.md` 第 105/557/563/565 行共 4 行;下節建議文字保留作決策紀錄,以 GDD 現文為準))

--- story-053-end-action-button-and-hide-finished-hint-bar.md
-> **Status**: Ready(2026-11-13,依 ux 定稿與命名/段落序裁決更新)—— 文案與禁用態**已由 ux-designer 定稿**(`docs/reviews/story-053-copy-final-2026-11-13.md`,**第 8 節取代前文**);🔴 兩項【未驗】須實作者落字前實測(AC7),不符停下回報
+> **Status**: ✅ Done-pending-visual(2026-11-16,提交 `3759352`;AC9 像素層 2026-11-16 四項目測通過,真實高亮壓框下的變淡待補拍)(原狀態:Ready(2026-11-13,依 ux 定稿與命名/段落序裁決更新)—— 文案與禁用態**已由 ux-designer 定稿**(`docs/reviews/story-053-copy-final-2026-11-13.md`,**第 8 節取代前文**);🔴 兩項【未驗】須實作者落字前實測(AC7),不符停下回報)

--- story-054-action-state-icons-sword-shoe.md
-> **Status**: Ready(2026-11-13,art 補遺已到)—— ⚠️ 兩項小待決不擋開工,但須在對應 AC 處停下回報:「做完變暗」的觸發定義(待 game-designer,見「派工前須確認」1)、DONE 單位被選取時是否恢復亮度(待 ux)
+> **Status**: ✅ Done-pending-visual(2026-11-16,提交 `0582b98`;AC8 像素層補拍 + 管理者本人盲測未做)(原狀態:Ready(2026-11-13,art 補遺已到)—— ⚠️ 兩項小待決不擋開工,但須在對應 AC 處停下回報:「做完變暗」的觸發定義(待 game-designer,見「派工前須確認」1)、DONE 單位被選取時是否恢復亮度(待 ux))

--- story-055-damage-preview-text-clipped.md
-> **Status**: 🔴 **Blocked(2026-11-13)—— 步驟 1 量測可先做;步驟 2 修法若動三帶版面,須 art-director + ux-designer 先選修法**(選項見下)
+> **Status**: ✅ Done-pending-visual(2026-11-16,提交 `1a5e886`;修法 = 血量 Label 改用 LabelSettings,未動三帶;AC2 僅 `30→15` 一例經開窗驗,其餘字串 × 兩解析度待補)(原狀態:🔴 **Blocked(2026-11-13)—— 步驟 1 量測可先做;步驟 2 修法若動三帶版面,須 art-director + ux-designer 先選修法**(選項見下))

--- story-056-campaign-defeat-retry-same-mission.md
-> **Status**: Ready(2026-11-13)—— 🔴 「下一步」行用字須 game-designer 定稿(見 AC4 與待決題 1);其餘可動工
+> **Status**: ✅ Done-pending-visual(2026-11-13,提交 `034ae30`;AC7 戰敗畫面像素層待補拍)(原狀態:Ready(2026-11-13)—— 🔴 「下一步」行用字須 game-designer 定稿(見 AC4 與待決題 1);其餘可動工)

--- story-057-piece-initial-dark-backdrop.md
-> **Status**: Ready(2026-11-16,管理者已裁決方案)—— 🔴 排序前置見最後一節(047 之後)
+> **Status**: ✅ Done-pending-visual(2026-11-16,提交 `7cc0d1f`;游標格首字洗淡依管理者裁決接受;AC7 管理者本人逐張看五位角色待確認)(原狀態:Ready(2026-11-16,管理者已裁決方案)—— 🔴 排序前置見最後一節(047 之後))
```

(上表共 21 檔;033 檔頭已正確,不改。)

### 4-2 `story-index.md`(只改狀態那一段;每列其餘欄位不動)

```diff
-| 021 | … | 自動對戰迴圈接上好感度加成。Ready(2026-10-28)(依檔頭;2026-10-30 補列) | — |
+| 021 | … | 自動對戰迴圈接上好感度加成。✅ Done(`2ab702a`,2026-10-28)(2026-10-30 補列) | — |

-…負向 Φ 減傷改進位。✅ Done(依提交 `e7751fc`,檔頭待改;檔頭現寫 Ready(2026-10-30)) | 031 |
+…負向 Φ 減傷改進位。✅ Done(`e7751fc`,2026-10-30) | 031 |

-…✅ Done(`289c837`;第 4 場 E3 改站保留、第 3 場整案退回零改動;檔頭 Status 行仍寫 Ready,其下 2026-11-10 加註已記完成) | — |
+…✅ Done(`289c837`;第 4 場 E3 改站保留、第 3 場整案退回零改動) | — |

-…✅ 程式完成(`34c2f2d`;正式圖 `86fde93` 入庫;AC-5~7 待在家驗收;檔頭 Status 行仍寫 Blocked,其下 2026-11-11 兩則加註已記改 Ready 與程式完成) | — |
+…✅ Done-pending-visual(`34c2f2d`;正式圖 `86fde93` 入庫;AC-5~7 待在家驗收) | — |

-…✅ Done(`f0884ac`;檔頭 Status 行仍寫 Ready,其下 2026-11-11 加註已記完成) | — |
+…✅ Done(`f0884ac`) | — |

-…✅ Done(依提交 `487b6e0`,檔頭待改;檔頭現寫 Ready(2026-11-12)) | — |
+…✅ Done(`487b6e0`) | — |

-…✅ Done(依提交 `c28bde9`,檔頭待改;檔頭現寫 Ready(2026-11-12)) | 039 |
+…✅ Done-pending-visual(`c28bde9`;AC6 待開窗) | 039 |

-| 041 | …(story-039 回歸)。✅ Done(依提交 `74fbce7`,檔頭待改;檔頭現寫 Ready(2026-11-12)) | — |
+| 041 | …(story-039 回歸)。✅ Done-pending-visual(`74fbce7`;AC6 待補拍) | — |

-| 042 | …資訊卡「遮蔽」改「擋視線」。✅ Done(依提交 `74fbce7`,檔頭待改;檔頭現寫 Ready(2026-11-12)) | — |
+| 042 | …資訊卡「遮蔽」改「擋視線」。✅ Done-pending-visual(`74fbce7`;AC5 待補拍) | — |

-…✅ Done(依提交 `7c0333e`,檔頭待改;檔頭現寫 Ready(2026-11-12)) | 041 |
+…✅ Done-pending-visual(`7c0333e`;AC8 有條件過,48 格後重拍) | 041 |

-…✅ Done(依提交 `278fb77`,檔頭待改;檔頭現寫 Ready(2026-11-12)) | 043 |
+…✅ Done-pending-visual(`278fb77`;AC7 待補拍) | 043 |

-…🟡 部分完成(依提交 `5c5602c`:AC1/3/4;AC2 選單入口未提交,檔頭待改;檔頭現寫 Ready(2026-11-12)) | 045 |
+…✅ Done-pending-visual(`5c5602c` AC1/3/4 + `bf05f56` AC2;AC6 待補拍) | 045 |

-…圖例面板:列出所有標記(顏色 + 形狀 + 一句話)。📋 Ready(2026-11-12) | 044、046 |
+…圖例面板:列出所有標記(顏色 + 形狀 + 一句話)。✅ Done-pending-visual(`f877533`;AC6 待補拍) | 044、046 |

-…🟡 部分完成(依提交 `1c07b32`:AC1;AC2 起未提交,檔頭待改;檔頭現寫 Ready(2026-11-12)) | 046 |
+…✅ Done(AC1,`1c07b32`);AC2 管理者 2026-11-16 裁決擱置(位置維持右上) | 046 |

-…+ 姓名鍵收斂。📋 Ready(2026-11-13) | 048 |
+…+ 姓名鍵收斂。✅ Done-pending-visual(`0bd5295`;AC7 待真 vs01 補拍) | 048 |

-…(空格不畫;GDD 已於 2026-11-13 同步)。📋 Ready(2026-11-13) | 044 |
+…(空格不畫;GDD 已於 2026-11-13 同步)。✅ Done-pending-visual(`8b8e339`;AC7 待補拍) | 044 |

-…滑鼠「結束行動」按鈕 + 結束畫面隱藏空底條。📋 Ready(文案待 ux 覆核) | 045、046 |
+…滑鼠「結束角色行動」按鈕 + 結束畫面隱藏空底條。✅ Done-pending-visual(`3759352`;AC9 真壓框待補拍) | 045、046 |

-…+ 做完變暗。⛔ Blocked(待 art 補遺併入) | 051 |
+…+ 做完變暗。✅ Done-pending-visual(`0582b98`;AC8 補拍 + 管理者盲測未做) | 051 |

-…傷害預覽「23→7」截字。⛔ Blocked(待開窗量測 + 修法選擇) | 041 |
+…傷害預覽「23→7」截字。✅ Done-pending-visual(`1a5e886`;AC2 其餘字串 × 兩解析度待補) | 041 |

-…(不回標題)。📋 Ready(2026-11-13;「下一步」行用字待 game-designer 定稿) | 046 |
+…(不回標題)。✅ Done-pending-visual(`034ae30`;AC7 待補拍) | 046 |

-…(管理者 2026-11-16「A:全部加濃底」)。📋 Ready | 055 |
+…(管理者 2026-11-16「A:全部加濃底」)。✅ Done-pending-visual(`7cc0d1f`;AC7 管理者逐張看五位待確認) | 055 |
```

⚠️ 4-2 的「`…`」代表該列前段原文不變;053 那列順帶把「結束行動」改為「結束角色行動」,是依交接檔第 9 行管理者裁決「全遊戲統一此名」 —— **這一處超出純狀態同步,若只要同步狀態請刪掉這半句改動。**

📌 **套用後可當場驗**:
`grep -c "檔頭待改" production/epics/tactical-combat/story-index.md` 應為 `0`;
`grep -m1 "^> \*\*Status\*\*" production/epics/tactical-combat/story-0{39,4,5}*.md` 不應再出現 `Ready(2026-11-1` 開頭(049、058 除外)。
