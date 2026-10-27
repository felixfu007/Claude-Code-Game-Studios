# 寫死行號引用 —— 逐處修正提案(2026-10-27,producer)

> **狀態**:提案,**未動任何既有檔**。協調者核准後依下表做精確替換。
> **規則來源**:`.claude/rules/design-docs.md` 的「No line-number self-references」條。
> **清單重現**(活文件 45 處,排除歷史審查紀錄):
> `bash .claude/hooks/validate-doc-consistency.sh --line-refs 2>&1 | grep -v "review\|cross-review\|revision-history\|rewrite-plan\|remediation\|suspected"`

## 給管理者的白話摘要

文件裡有 45 處寫著「見某檔第 N 行」。行號會因為上方插入文字而位移,位移後那句話就會把讀者帶到錯的段落 —— 而且不會報錯,讀者只會讀到一段不相干的內容然後照做。

逐處打開核對後的結論:

| 判定 | 處數 | 意思 |
|---|---|---|
| **A 改** | **17 處**(合併成 14 次替換) | 這句話現在仍在「指路」。改成用章節標題、條目編號或函式名指路,以後不會再漂。**14 次替換中有 7 次的目標今天已經指錯了**(表中標「已漂移」)。 |
| **B 不改** | **28 處** | 都是修訂紀錄裡描述「當時第 N 行有什麼問題」的歷史敘述。改掉等於竄改紀錄;而且其中多數已經自己寫了「原寫第 N 行,已漂移」,本身就是在記錄這條規則被違反的歷史。 |
| **C 誤報** | **0 處** | 45 個數字全部確實是行號或列號,沒有色號、像素、次數之類被誤抓。 |

**改了會怎樣**:那 7 次已指錯的,讀者今天照著走會找到錯的東西(例如一處指向「暫停裁定」函式,實際該行號現在落在別的程式碼上,差了 64 行;另一處是一條仍未關閉的跨系統義務的「怎樣才算完成」,它指向的行今天落在不相干的段落)。另 7 次今天還對,但下次有人在上方加一段就會錯。
**不改會怎樣**:沒有東西會壞掉或報錯 —— 只是錯的指路繼續存在,等下一個人照著走。這一批**不急**,但改動是純機械替換、風險很低。

⚠️ 17 處裡有 **10 處(7 次替換)指向的是程式碼、引擎參考檔、審查報告或實驗紀錄**,不是設計文件 —— 規則字面只管設計文件、`systems-index.md` 與審查紀錄。這 9 處在表中標 **A\*(超出規則字面)**,理由是同樣會漂、且已有 3 處漂了;要不要一起改是您的選擇,不改也不違反規則。

## A 類:逐處替換表

「已漂移」= 今天打開目標檔,原行號已不是原意那一行。
🔴 **替換時的取字範圍**:片段是**最外層反引號之內**的文字;外層用 ` `` ` 包住時,緊貼外層反引號的那**一個**空格是 markdown 包裝,不屬於片段。舊片段唯一性已以 `grep -oF -- "<片段>" <檔> | wc -l` 逐條確認 = 1(14 條)。

| # | 檔案 | 原行號(命中數字) | 判定 | 舊片段(逐字,已確認在該檔唯一) | 新片段(逐字) | 核對依據 |
|---|---|---|---|---|---|---|
| A1 | `design/art/art-direction.md` | 110(471) | A\* 程式碼 · **已漂移** | ``建立的血量數字 `Label`,約第 471 行)`` | ``建立的血量數字 `Label`;位置當場查:`grep -n "Label.new" src/ui/battle/board_view.gd`)`` | 該 `Label.new()` 今天在第 807 行(`_build_hp_text()` 起於 792),差 336 行。上述 grep 今天只有 1 處命中,正是它。字型缺口本身仍在(`board_view.gd` 字型關鍵字命中 0)。 |
| A2 | 同上 | 112(945、952) | A\* 程式碼 · **已漂移** | `` `text_label`〔約第 945 行〕與 `effect_label`〔約第 952 行〕)`` | `` `text_label` 與 `effect_label`;位置當場查:`grep -n "Label.new" src/ui/battle/hand_bar.gd`)`` | 今天在 1069 / 1076(`_ensure_detail_panel()` 起於 1057)。該 grep 今天恰 2 處命中,正是這兩個。 |
| A3 | 同上 | 134(22) | A\* `.tscn` · **已漂移** | ``第 22 行)在 `_apply_layout()` 統一套用`` | ``裡該節點的 `script` 屬性)在 `_apply_layout()` 統一套用`` | 前一行結尾是「(掛在 `UILayer` 節點,`BattleScreen.tscn`」,接起來讀作「…`BattleScreen.tscn` 裡該節點的 `script` 屬性)」。今天 `UILayer` 節點在第 24 行、`script = ExtResource("4_hud_layout_scaler")` 在第 25 行。 |
| A4 | `design/art/cheyenne-probe-prompts-2026-10-19.md` | 28(123) | A\* 審查報告 · **已漂移** | `第 123 行引用的也是這份)` | `第二節「立繪-C」候選的第 2 點風險引用的也是這份)` | 目標 `docs/reviews/base-model-feasibility-v2-2026-10-19.md`,引用 `04-security-and-licensing.md` 第 5.3 節的那句今天在第 124 行,位於「#### 立繪-C:_CHEYENNE_」小節的第 2 點。前一行結尾是「(`base-model-feasibility-v2`」,接得上。 |
| A5 | `design/quick-specs/mvp-five-levels-skeleton.md` | 40(456) | A | `` `game-concept.md` 第 456 行要求`` | `` `game-concept.md`「MVP 定義」節「MVP 必要內容」第 3 條要求`` | 今天第 456 行仍是該條(「至少 5 場手工關卡,其中至少 1 場…探針關卡」),位於 `## MVP 定義`(433)下的「**MVP 必要內容**」清單第 3 項。原意吻合,未漂。 |
| A6 | 同上 | 69(455) | A | `` `game-concept.md` 第 455 行要求`` | `` `game-concept.md`「MVP 定義」節「MVP 必要內容」第 2 條要求`` | 今天第 455 行仍是第 2 項(「至少涵蓋 2 組正好感、2 組負好感配對」)。未漂。 |
| A7 | `design/quick-specs/support-conversation-system.md` | 6(55) | A | `` `design/gdd/systems-index.md` 第 55 列(2026-08-25)`` | `` `design/gdd/systems-index.md`「Systems Enumeration」表 #8「支援對話系統」列(2026-08-25)`` | 今天第 55 列 = `\| 8 \| 支援對話系統 \| …`,內含「2026-08-25 範圍降級的連帶處置 … 寫死的觸發點 … 不需要排程系統」,正是本檔引述的內容。未漂。 |
| A8 | 同上 | 19(55) | A | ``(`systems-index.md` 第 55 列)`` | ``(`systems-index.md`「Systems Enumeration」表 #8 列)`` | 同 A7。 |
| A9 | `design/quick-specs/unit-stats-provisional.md` | 259(93) | A | `` `affinity-position-provisional.md` 第93行起`` | `` `affinity-position-provisional.md` 第 3 節「已裁決:`Φ` 只作用於我方發起的攻擊」小節`` | 今天第 93 行仍是 `### 🔴 已裁決：\`Φ\` 只作用於我方發起的攻擊`(屬 `## 3. Φ 的暫定幅度`)。⚠️ 原標題用**全形冒號**「：」;新片段刻意不抄 emoji 與冒號形,只取可辨識的標題文字,以免抄錯一個字元變成找不到。未漂。 |
| A10 | `design/ux/battle-menu.md` | 351(364、376) | A\* 程式碼 · **已漂移** | ``第 364 行(`suspend_arbitration()`)與第 376 行(`resume_arbitration()`),`` | ``的 `suspend_arbitration()` 與 `resume_arbitration()`,`` | 今天在 `cursor_state_host.gd` 第 428 / 440 行,差 64 行。前一行結尾是「`src/ui/cursor/cursor_state_host.gd`」;下一行本來就附了 `grep -rn "^func suspend_arbitration\|^func resume_arbitration" src/`,故刪行號不損失定位能力。 |
| A11 | `design/gdd/systems-index.md` | 268(170) | A · **已漂移** | ``回填 `save-system.md` Dependencies 第 170 列`` | ``回填 `save-system.md` Dependencies 表「章節/戰役結構(尚未設計)」列`` | 此為 `OBL-036` 的關閉條件(活義務)。今天 `save-system.md` 第 170 行落在 Core Rules 內,與 Dependencies 無關。**原意推斷**:句子自己寫「Dependencies」,而該表唯一與「自動存檔觸發點/章節開始」相關的列是「章節/戰役結構(尚未設計)\| 呼叫方,寫入觸發來源 \| 決定自動存檔的實際觸發時機點(例如…每章開始/結束)」,與 OBL-036 主題逐字對應。⚠️ 該行號在寫入當下(`4c25b9d`,2026-08-07)就已對不上 —— 該提交版本的第 170 行是一列矩陣,該 Dependencies 列在第 247 行;推測是對著提交前的中間版本寫的。只動該列「關閉條件」欄的一個片段,不動 `OBL-036` 號碼,不牴觸登記表三條硬規則。 |
| A12 | `docs/architecture/adr-0005-cursor-device-authority-input-architecture.md` | 131(43) | A\* 引擎參考檔 | `` `breaking-changes.md` 第 43 行標 4.4→4.5 為`` | `` `breaking-changes.md` 的「4.4 → 4.5」節標題標 4.4→4.5 為`` | 今天第 43 行仍是 `## 4.4 → 4.5 (Late 2025 — POST-CUTOFF, HIGH RISK)`。未漂。 |
| A13 | 同上 | 133(384、59) | A\* 實驗紀錄 | `(該 README 第 384 行、log 第 59/76/83 行)` | ``(該 README 的「F-4 · Agile Event Flushing 的鍵名 ADR 猜對了」節、`logs/run-final-2026-08-20-headless.txt` 中 `grep -n "agile_event_flushing"` 的三處命中)`` | README 第 384 行今天落在 `#### F-4 · Agile Event Flushing 的鍵名 ADR 猜對了 …`(379)節內,未漂;log 以 `grep -n "agile_event_flushing"` 今天恰命中 59/76/83 三行,與原文一致。log 是不會再改的實驗產物,行號本身其實穩定 —— 改它只為讓這一處整句不再被工具抓到;若協調者偏好最小改動,可只改 README 那半句。 |
| A14 | 同上 | 1202(98) | A · **已漂移** | `核對 GDD 第 98 行原文確認丙不在內` | `核對 GDD Core Rules #7「觸發情境明文擴充涵蓋存檔載入」段的(甲)(乙)分支原文確認丙不在內` | 寫入當下(`5593d58`,2026-08-19)GDD 第 98 行是「(乙)無舊表面時讀檔」;今天第 98 行是「(甲)舊表面存在時讀檔」—— 漂了 1 行。**原意推斷**:句子論點是「GDD 只要求甲/乙重置、丙不在內」,故指向甲/乙兩分支所在段落(今天 97~99 行,段首為「觸發情境明文擴充涵蓋存檔載入」)。 |

## B 類:不改(28 處)

全部是修訂紀錄或稽核註記裡描述「當時」的歷史敘述。逐處列出,供協調者抽查。

| 檔案 | 原行號(命中數字) | 為何是歷史敘述 |
|---|---|---|
| `design/gdd/affinity-data-pool.md` | 7(86) | 檔頭第十二輪修訂紀錄:「`game-concept.md` 第 86 行輪次標籤誤標修正」—— 描述 2026-08-10 當時修了什麼 |
| 同上 | 21(294) | 檔頭第九輪修訂紀錄:「修正第 294 列失效的舊標題交叉引用」—— 同上 |
| `design/gdd/cursor-highlight-state.md` | 6(76) | 第十五輪紀錄,**本身就在記載「以行號〔第 76/78/290 行〕引用已改為穩定指標」這件事** |
| 同上 | 7(76)、7(166) | 第十四輪紀錄:「經直接核對 `save-system.md` 第 76/78/290 行證實為假」「Registry 第 166 列同步更新」—— 當時的查證動作 |
| 同上 | 8(166) | 第十三輪紀錄:「`systems-index.md` 第 166 列已同步更新」 |
| 同上 | 10(165) | 2026-08-11 局部修訂紀錄:「Registry 第 165 列同步擴充」 |
| 同上 | 102(165)、102(203) | 2026-09-01 稽核註記:「原『第 165/166 列』改為內容定位 —— 該行號當時已漂移至第 203 列」;該句前方已有內容定位(「該列以『若下游 UI 表面自身即為…』起頭」) |
| 同上 | 104(165)、104(203) | 同上,同一則稽核註記的另一處 |
| 同上 | 360(165)、360(203) | 同上 |
| 同上 | 391(205) | 2026-09-01 稽核註記:「原寫 `(line 172)` … 目標在第 205 列,漂移 33 列」;句中已有內容定位(「該節列『`/art-bible` 須補上主機專屬規格』的那一條」) |
| `design/gdd/game-concept.md` | 134(180) | 第十二輪修正說明:「`systems-index.md` 登記表第 180 列皆記載為第十一輪」—— 當時的證據 |
| `design/gdd/save-system.md` | 345(165)、345(203) | 與 cursor-highlight 102 同一則 2026-09-01 稽核註記;前方已有內容定位 |
| 同上 | 463(88) | 2026-09-01 稽核註記:「原寫『第 88 行』,該行是空行 … 漂移 48 列」;前方已改為內容定位(「過渡期殘餘風險聲明」段) |
| `design/gdd/systems-index.md` | 12(165) | 2026-08-11 更新紀錄 |
| 同上 | 15(164) | 2026-08-07「前次更新」紀錄 |
| `design/gdd/tactical-combat-system.md` | 368(26) | 2026-09-01 稽核註記:「原以『第 26 列』指路 … 已漂移」;句中已改為以列名指路 |
| `docs/architecture/adr-0004-…-execution-model.md` | 531(27)、531(421) | 「2026-08-19 修訂」說明:「與同檔第 27 行、第 421 行已於 `1c3d5d0` 修正的…矛盾」—— 釘在一個提交上的歷史敘述 |
| `docs/architecture/adr-0005-…-input-architecture.md` | 77(705)、77(774) | 修訂紀錄:「協調者另發現其中第 705 行的『三者』在本次修訂之前就已與第 774 行的『四個』不一致」 |
| `docs/architecture/traceability-index.md` | 248(434) | 2026-10-15 事實層修訂註記:「原寫『第 434 行』,實測該行是…」—— 已改用引號句當錨 |
| 同上 | 253(714) | 同上:「原寫『第 714 行』,實測已漂移」;已附 grep 指令 |
| 同上 | 273(216) | 2026-09-08 更正說明:「協調者當日反向搜尋…只搜到同檔第 216 行」—— 描述當日搜尋過程 |

📌 **B 類有一個副作用要知道**:它們會永遠留在 `--line-refs` 清單上。這個工具不分辨「指路」與「敘述」,所以清單不會歸零 —— 改完 A 類後活文件預期剩 28 處,**28 不代表還有沒修的**。

## 清單外、本輪不處理但應知道的事

1. **工具抓不到的指路行號**(所以「45 處」不是全部):
   - 範圍寫法:`traceability-index.md` TR-cursor-013 列寫「機制三第 250–256 行」(全形破折號,工具的 regex 不認範圍)—— 這是**活的指路**。另外,該列宣稱「全文沒有任何一句說 `is_valid` 是否參與比較」,而 ADR-0005 今天有一行寫「equals() 依機制三定案**不看 is_valid**」(`grep -n "不看 is_valid" docs/architecture/adr-0005-cursor-device-authority-input-architecture.md`)—— **該列的論點本身可能已經過時**,超出本輪範圍,屬 `technical-director` 判斷。
   - 冒號寫法 `檔名.md:107`(例:`base-model-feasibility-v2` 第 23 行)—— regex 不認。
   - 數字 ≤ 14 的一律略過(工具自己的門檻)。
2. **`art-direction.md` 已知缺口那一節的「逐字證據」區塊**貼的是 2026-09-23 的 grep 原始輸出(`75:` / `832:` / `846:`),今天實測是 `943:` / `957:`。那是當日快照、不該改,但它緊鄰 A1/A2 —— 讀者可能拿它當現值。建議(非本輪範圍)在區塊上方加一句「2026-09-23 快照」。
3. 本輪未複驗 `art-direction.md` 那個字型缺口是否仍待修 —— 只順手確認了它**仍在**(`board_view.gd` 字型關鍵字 0 命中;`hand_bar.gd` 兩個詳情 `Label` 無覆寫)。

## 規則 4 疑慮(同一份文件不做第三次以上修訂)

只列出,不解決。「修訂」怎麼數本專案沒有明文定義;下列以提交數作參考,**提交數不等於修訂次數**。

| 檔案 | 2026-08-25 後提交數 | 疑慮 |
|---|---|---|
| `docs/architecture/adr-0005-…-input-architecture.md` | 16 | 最可能有疑慮。規則 4 明文「不追改已完成的 5 份 ADR」是指不拿新規則回頭砍,但本次是**新的一次修改**。ADR-0001 的先例是「到第三次就重寫」。A12~A14 都是零決策變更的指路修正,但它仍是一次修改。 |
| `design/gdd/systems-index.md` | 23 | 它是索引/登記表,持續增列是它的常態用法,規則 4 是否適用於它本身就有疑義。A11 只動一個關閉條件欄的片段。 |
| `design/art/art-direction.md` | 9 | 若按提交數計已遠超三次;但多數是不同章節的新增。 |
| `design/ux/battle-menu.md` | 8 | 同上。 |
| `design/quick-specs/unit-stats-provisional.md` | 7 | 同上。 |

其餘三份(`cheyenne-probe-prompts`、`mvp-five-levels-skeleton`、`support-conversation-system`)提交數 1~2,無疑慮。
