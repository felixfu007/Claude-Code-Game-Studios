# ADR-0003 修訂 —— 進度檢查點

草案檔:`scratchpad/adr0003/draft.md`(正式檔尚未動)
正式檔:`docs/architecture/adr-0003-save-system-serialization-format-and-type-safety.md`

## 流程(管理者裁決:必須 --review full)
寫草案 → Step 5.5 完整覆核(引擎專家 + TD-ADR)→ 修 → 窄範圍覆核 → 才寫入

## 修訂範圍(已與管理者確認)
6 組必修 + 7 項一行級。兩個與紀錄不符之處已納入:
- 紀錄「18 處」只涵蓋呼叫寫法,另有 2 處獨立的 allow_objects 文字宣稱(行 66、309)同樣為假
- 第 1 組不是純改字:行 66 的「不依賴預設值、顯式傳 false 是縱深防禦」論證整個蒸發

## 進度
- [x] 第 1 組機械部分:17 處呼叫 + 行 20 簽章 = 18 處,已替換為單引數
- [ ] 行 17 Knowledge Risk —— 「無 core/scripting 模組文件」已成假(今日已建兩份)
- [ ] 行 18 References Consulted —— 補兩份新模組檔
- [ ] 行 20 Verification Required 五項 —— 多數已被探針關閉,須整段重寫
- [ ] 行 58 Decision 首段 —— 禁令範圍擴及 FileAccess(E3)
- [ ] 行 62 核心洞見 —— 補寫入側靜默成功的相反方向
- [ ] 行 66 機制一 —— 論證重寫 + 刪「自訂」二字(H-7)
- [ ] 行 191-192 示意圖括號已成假(H-2b)
- [ ] 行 290 / 297 / 338 —— VR#2 推測已成實測
- [ ] 行 308-309 TR-save-002 —— allow_objects 宣稱
- [ ] 第 2 組 雜湊輸入改固定順序陣列
- [ ] 第 3 組 寫入側+讀取側遞迴型別閘門(深度上限 + DEPTH_EXCEEDED + size()>0)
- [ ] 第 4 組 HashingContext 規則(含 hash_matches())
- [ ] 第 5 組 is Dictionary + 信封形狀檢查
- [ ] 第 6 組 serialize_manifest/deserialize_manifest + SaveWriter
- [ ] 一行級 7 項

## 證據來源(只用這些,不用 ADR 自己的舊宣稱)
- docs/engine-reference/godot/modules/core-serialization.md(今日建,逐條附 log 引用)
- docs/engine-reference/godot/modules/scripting-typing.md
- prototypes/xcheck-adr0003-2026-08-21/ 探針 F/G/H/J
- prototypes/save-format-skeleton-2026-08-21/ 骨架

---

## 2026-08-24 管理者指示:改為委派專業人力

原本協調者(我)自己在寫全部六組。管理者指出應交給對應領域的 agent。
**已重新分工,三路並行:**

| 專家 | 負責 | 為什麼是他 |
|---|---|---|
| `godot-gdscript-specialist` | 第 3、5、6 組的 GDScript 契約 | File Extension Routing 表明訂 .gd 契約歸他 |
| `godot-specialist` | 第 2、4 組(雜湊順序 / HashingContext 規則)+ **覆核協調者已寫的 line58/line62/檔頭** | 引擎 API 權威;core-serialization.md 是他寫的 |
| `security-engineer` | 寫入側閘門的威脅模型與必須涵蓋範圍 | 閘門的目的是防 Object/RID/Signal 夾帶進存檔——這是安全題,原本漏找 |

**刻意讓 security 與 gdscript 獨立平行**:一個定「必須擋什麼」,一個定「程式形狀」,
兩軌獨立收斂才有交叉驗證價值(ADR-0002 第四次修訂的兩軌獨立收斂抓到 3 個不可達值)。

**協調者保留的職責**:發現清冊、範圍守門、三份產出的整合與矛盾裁決、
Step 5.5/5.6 正式覆核的發動、以及寫入前請管理者核准。

## 待協調者處理(收到三份產出後)
- [ ] 三份產出交叉比對,找矛盾(尤其 security 的「必須擋」清單 vs gdscript 的允許集合)
- [ ] 整合進 draft.md
- [ ] 第 1 組剩餘的文字段落(line58/62 待 godot-specialist 覆核後才拼入)
- [ ] 一行級 7 項
- [ ] Step 5.5(引擎專家覆核完整草案)+ 5.6(technical-director TD-ADR)
- [ ] 窄範圍複驗 → 請管理者核准 → 寫入 → registry

---

## 2026-08-24 第二輪派工(專家直接寫檔,協調者不再轉述)

**做法改變的原因**:第一輪三位專家的產出只存在對話中,壓縮後全部消失,只留下
`CROSSCHECK.md` 的摘要 —— 而我在寫那份摘要時把兩段程式碼的出處誤記成骨架
(骨架其實沒有那兩段)。**第二輪起專家直接把成品寫成檔案。**

### 已交付

| 檔案 | 作者 | 規模 | 狀態 |
|---|---|---|---|
| `section-mechanism-1b.md` | godot-gdscript-specialist | 726 行 / **46.6 KB** | ⚠️ 太大,已退回精簡(見下) |
| `section-mechanism-4b.md` | godot-specialist | 195 行 / 11.8 KB | ✅ 可用 |
| `line62-REWRITE.md` | security-engineer | 282 行 / 20.8 KB | ✅ 可用 |
| `line58-DRAFT.txt` | godot-specialist 修訂 | 13 行 | ✅ 「共用線格式」已標為推論 |

### 規模問題(必須在併入前解決)

| 對照 | 大小 |
|---|---|
| 現行整份 ADR-0003 | 52.6 KB |
| 三份新產出合計 | **79 KB** |
| 併入後推估 | **132 KB(2.5 倍)** |
| ADR-0005(已被管理者列為「是否凍結」待決,理由是太大沒人能覆核) | 247 KB |

→ 已退回 `godot-gdscript-specialist`,目標 **進 ADR 的版本 ≤ 15 KB**,原則是
**按性質分流**:引擎量測敘述回 `core-serialization.md`(已存在、已進索引)、
ADR 只留規範性契約、誠實標記一律不砍。原 726 行檔保留作紀錄。

### 進行中的三路派工

| 派給誰 | 事項 |
|---|---|
| godot-gdscript-specialist | 精簡至 ≤15 KB + **列出參考庫目前缺少的引擎事實**(這份缺口清單會另外派工補回參考庫) |
| security-engineer | 裁決 `GateResult` 物件 vs bool —— gdscript **正面覆蓋了 security 自己的警告**,該由他判成不成立 |
| godot-specialist | 重寫行 151 與行 309(**新發現的第三處過度宣稱**,見 CROSSCHECK) |

### 本輪協調者自己抓到的兩件事

1. **假宣稱有三處,紀錄只算到兩處** —— 行 151 從未在任何清單上。方法是搜尋「宣稱家族」
   而非搜尋手上已知的字串。這是 `consistency-failures.md` 模式 C 的預防。
2. **「深度數字差一」這個登記本身是錯的** —— 兩種說法各自成立,只是那個數字沒有單位。
   根治法是改用比較式 `depth > MAX_PAYLOAD_DEPTH` 描述,不用裸數字。

---

## ✅ 2026-08-24 完成:修訂已寫入正式檔

**管理者核准兩項**:(1) 寫入正式檔,並同時登記四條跨文件規則;(2) 核准後把實測證據搬到參考庫。

| 項目 | 結果 |
|---|---|
| 正式 ADR | 350 行 / 52.6 KB → **1345 行 / 120.7 KB**,與草案逐位元組相同(`cmp` 驗過) |
| `Status` 欄 | **仍為 `Proposed`** —— 管理者核准的是「寫入」,是否改 `Accepted` 為另一個未問的決定 |
| 登記表 | 81 → **85 項**(10 state / 11 interface / 29 api / **35** forbidden,逐節實測) |
| 過期警告牌 | ✅ 已拆 —— `save_serialization_format` 的 DELIBERATE DIVERGENCE 改為 RESOLVED |
| 一致性檢查 | exit 0,**零 ERROR 級**(殘餘 warn 全在未觸碰的 GDD 檔) |

### 兩道正式關卡

| 關卡 | 判定 |
|---|---|
| Step 5.5 引擎專家(未參與撰寫) | `CONCERNS` → 引擎事實**零錯誤**,四項一致性缺陷,全數修畢 |
| Step 5.6 TD-ADR(**本專案史上第一次執行**) | `CONCERNS` 10 項 → 全數關閉 → 窄範圍複驗 **`APPROVE`** |

**四個核准條件複驗後全部成立。**

### 下一步(依核准的選項 A)

把實測證據搬到 `docs/engine-reference/godot/modules/core-serialization.md`,
ADR 只留結論 + 連結,目標回到 600-700 行。
⚠️ **搬家只准剪下貼上、不准改寫任何一句**,搬完做逐字比對。搬家不改決定,故不需重新核准。
