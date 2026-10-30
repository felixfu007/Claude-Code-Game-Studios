# 協議 2 attempt-1 判定(qa-lead,2026-10-30)

> 依據:`docs/reviews/protocol2-threshold-locked-2026-10-30.md`(下稱「鎖定文件」)2.3 與 4.1 第 5 點。
> 原始資料:同目錄 `raw_stdout.txt`(下稱 raw)。本判定**未修改任何規則**。

## 0. 鎖定鏈與執行有效性(自行重跑,不採信轉述)

| 檢查 | 指令/來源 | 實際輸出 |
|---|---|---|
| H 是鎖定文件最後一次修改 | `git log -1 --format=%H -- docs/reviews/protocol2-threshold-locked-2026-10-30.md` | `20e0854d5c30...`(開頭 = H `20e0854`)✅ |
| H 早於 V | `git merge-base --is-ancestor 20e0854 6b6f1c2` | exit 0(`ok-H-V`)✅ |
| V 早於 R | `git merge-base --is-ancestor 6b6f1c2 6835840` | exit 0(`ok-V-R`)✅ |
| 結果檔首次提交 | `git log --diff-filter=A --format='%h %cI' -- production/qa/protocol2/` | `6835840 2026-10-30T09:20:50+08:00`(= R)✅ |
| V→R 程式目錄無變動 | `git diff --stat 6b6f1c2 6835840 -- prototypes/protocol2-computer-measure/` | 空 ✅ |
| H→R 鎖定文件無變動 | `git diff --stat 20e0854 6835840 -- docs/reviews/protocol2-threshold-locked-2026-10-30.md` | 空 ✅ |
| V→HEAD 程式目錄無變動 | 同上改 HEAD | 空 ✅ |
| 引擎 exit / 完整性 | `RUN-INFO.md`;raw 第 20 行 | `ENGINE EXIT = 0`、`DONE` 存在;`grep -c "^RESULT"` = **16** ✅ |
| 關卡/上限 | raw 第 3 行 HEADER | `level=1 terrain=res://assets/data/levels/vs01_terrain.txt ... max_rounds=12`,`build_commit=6b6f1c20...`(= V)✅ |

結論:鏈條成立、本次執行有效,可判定。

## 1. 步驟 A 基準有效性(忽視臂通關數須在 2~6)

忽視臂 8 行(raw 第 4、6、8、10、12、14、16、18 行):
```
ignore v=0 outcome=VICTORY rounds=5 neardeath=1
ignore v=1 outcome=VICTORY rounds=5 neardeath=1
ignore v=2 outcome=VICTORY rounds=5 neardeath=1
ignore v=3 outcome=VICTORY rounds=5 neardeath=1
ignore v=4 outcome=DEFEAT  rounds=3 neardeath=5
ignore v=5 outcome=DEFEAT  rounds=3 neardeath=5
ignore v=6 outcome=DEFEAT  rounds=3 neardeath=5
ignore v=7 outcome=DEFEAT  rounds=3 neardeath=5
```
忽視臂通關 = **4**(v0~v3)。4 ∈ [2, 6] ⇒ **基準有效**,進入步驟 B。

## 2. 步驟 B

運用臂 8 行(raw 第 5、7、9、11、13、15、17、19 行):v0~v3 `outcome=DEFEAT rounds=4 neardeath=5`;v4~v7 `outcome=DEFEAT rounds=4 neardeath=5`。運用臂通關 = **0**。

**B1(a)通關率**:運用 − 忽視 = 0 − 4 = **−4**,門檻 ≥ +2 ⇒ **不成立**。
**B1(b)回合中位數**:須兩臂通關局數**各 ≥4**才可評估;運用臂通關局 = 0 < 4 ⇒ 依鎖定文件 2.3 本支**視為不成立**(不評估、不硬算)。(參考:忽視臂通關局回合 5,5,5,5,中位 5。)
⇒ **B1 不成立**。

**B2 瀕死**(算式,鎖定文件 2.2:戰敗局記我方單位總數 = 5):
- 運用臂總和 = 8 × 5 = **40**
- 忽視臂總和 = 4 × 1 + 4 × 5 = **24**
- 條件「運用 ≤ 忽視」:40 ≤ 24 ⇒ **不成立**。

2.3:B1 且 B2 同時成立才通過。**兩者皆不成立。**

## 3. 判讀限制(鎖定文件 2.4)與揭露

1. 本結果為「**電腦對照判定**」,不是玩家行為證實;兩臂皆為工程師寫的策略。
2. 8 個變體不是獨立樣本。**事實揭露**:v0~v3 的四個變體各臂 RESULT 行逐字相同,v4~v7 亦然(raw 全文可見)—— 實際只出現 2 種不同結果,K2、K3 旋鈕在本次輸出中未造成可見差異(鎖定文件 3.2 第 2 點已預告此情形不視為異常)。有效變體數遠小於 8。
3. 運用臂為「溫和運用」的限制見下方第 4 節:實作與鎖定文字**不一致**。
4. **Φ_avg 揭露**(操作檢查,不改分組、不作廢):忽視臂 1.200(v0~v3)、−0.667(v4~v7),皆 ≤ +4,未觸發紅字揭露線;運用臂 9.000(v0~v3)、6.500(v4~v7)。忽視臂未見高 Φ。

## 4. 對 ai-programmer 兩項解讀的判斷(僅記錄,不改規則)

**(1)運用臂步驟②先過濾再集火 —— 與鎖定文件【不符】。**
README「Implementation notes」寫:運用臂以 `bonus_for_at` 取最大值的格子**先過濾候選池**,集火與攻擊可行性在過濾**之後**才算,「affinity is a hard first priority and can cost an attack opportunity」。鎖定文件 3.1 寫運用臂「保留 `caff`/`aff` **決勝邏輯**(現 C)」,2.4 寫好感度「只在**同等可攻擊的格子間決勝**與集火結合,屬**溫和運用**」。現 C(`prototypes/autoplay-balance-2026-10-28/autoplay_v2.gd` 的 `_decide_cautious`)確實只在可攻擊性相同時才以 aff 決勝(`(not a.is_empty()) == (not ca.is_empty())`)。ai-programmer 的實作使好感度**優先於能否攻擊**,即「強硬優先」,而非鎖定文件描述的「溫和決勝」。
- 這是鎖定文件文字含混(3.2 未明列步驟順序,只在 3.1/2.4 以「決勝」描述)加上實作選了另一種字面讀法的結果,**實作偏離了 2.4 的明文描述**。
- 對本判定的影響:**本判定不因此改變**(鎖定規則一律照已執行的結果算,且 4.1 第 4 點限重跑於工具故障)。但本次運用臂 8/8 戰敗、Φ_avg 高達 9.0/6.5,與「為站位犧牲攻擊」的行為相符(推論,未逐回合驗證)。**是否視為工具缺陷、是否另開 attempt,由管理者裁決**;我不自行建議改法。

**(2)瀕死掃描時機 —— 實質符合。** 鎖定文件 2.2 要求「每次攻擊結算後掃描」;README 為每次 `decide` 呼叫開頭掃一次(= 上一動作結算後的狀態)外加 `run()` 結束後再掃一次。除非動作內部有回血(未見證據,未查證),每次攻擊結果都會被看到。且即使此處有誤差,**也不影響結論**:B1 已不成立,未通關局瀕死數本來就固定記 5。

## 5. 結論

# 未通過

(依據:A 有效 → B1(a) −4 < +2、B1(b) 運用臂通關局 0 < 4 不可評估、B2 40 > 24。結論不是「基準無效」。)

## 6. 給管理者的白話
1. 這次電腦對照有效,結果是「**未通過**」。
2. 「不看好感度」那邊 8 組贏了 4 組;「看好感度」那邊 8 組全輸。
3. 規則要求看好感度那邊至少多贏 2 組,結果是少贏 4 組,而且險況(差點死)也更多。
4. 8 組其實只有 2 種不同結果,不是 8 個獨立樣本。
5. 🔴 要你知道的一件事:電腦「看好感度」的版本把「站好感度位置」排在「能不能攻擊」之前,比我們鎖定時寫的「只在同樣能攻擊時才看好感度」更強硬,很可能因此輸掉。這個偏差我記錄了,但**沒有改規則、沒有改判定**。
6. 依停損約定,「協議 2 未通過」是需要你面對的結果;這次是電腦對照單次嘗試,是否承認、是否因第 5 點另開一輪,是你的裁決。
7. 鎖定鏈(門檻早於結果)我已自行驗證成立。
