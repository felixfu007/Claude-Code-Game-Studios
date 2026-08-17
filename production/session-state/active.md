# Active Session State

<!-- STATUS -->
Epic: 設計階段(Core Layer GDD)
Feature: 戰棋移動與交戰系統
Task: /design-review 第三輪修訂已落地,待 commit 與第四輪覆核
<!-- /STATUS -->

**最後更新**:2026-08-17 —— `/design-review design/gdd/tactical-combat-system.md` 第三輪(目標型覆核)

---

## 本 session 完成的事

`/design-review` 第三輪目標型覆核(`qa-lead`、`godot-specialist`、`ux-designer` 三位;`creative-director` 未諮詢,綜整由主 session 執行)。判定 **NEEDS REVISION**:**7 項 BLOCKING-NOW 全為設計內容缺陷** + 2 項傳播失敗 + 8 項 ADVISORY,**全部已於同輪修訂落地**。

### 本輪最重要的一項結構性改動

**新增 Core Rules #10「對外查詢介面的共用義務」總則 + AC-22**(使用者裁決:總則式修法,而非第三次逐項補條款)。

起因:查詢介面的**數學定義本身不足以**保證互動式 UI 的正確性 —— 這是本文件連續三輪各自獨立撞到的同一缺口。第一輪為預判模式補了 Edge Cases 條款 + AC-11;第一輪 BLOCKING #4 為移動/攻擊疊加圖補了另一條 + AC-20;第三輪又發現第二輪才新增的 §1 回合旗標總覽與 §1a 威脅範圍疊加圖**同樣沒補**。逐一補個案條款已三次證明每次都漏掉下一個。

總則含三項義務:(a) **即時性**(輸出恆等於以呼叫/重繪當下狀態從頭重算一次;可快取但輸出不得偏離斷言)、(b) **單一快照原子性**(跨幀計算須對計算開始時的同一份盤面快照完成;不禁止跨幀)、(c) **佔位資料所有權**(`occupied(tile)` 不得由場景/節點樹存在性導出 —— 引擎延後移除節點的語意會違反 AC-7(c) 的同結算步釋放)。

AC-11/AC-20 保留在冊,改標為總則的**具名實例**;新增查詢介面由 AC-22 直接涵蓋,不需再各自補 AC。

### 其餘六項 BLOCKING-NOW

- **F3-1**(視線幾何,主 session 驗算發現,推翻 `godot-specialist` 的相反主張):穿角規則的觸發條件寫成 `|dx| = |dy|` 是**錯誤的等價敘述**。正確充要條件為 `v₂(|dx|) = v₂(|dy|)`,故 `(1,3)`/`(3,1)`(皆 `d=4`,正好在遠程 `max_range` 上)同樣穿角卻落在規則外。已修正並補 AC-16 向量。
- **F3-2**:多穿角點的組合規則未定(`(2,2)` 有兩個穿角點加一個穿格心中繼格);AC-5 對角向量寫「中繼格集合可能為空」與規則互斥、不可測。Edge Cases 穿角條款重寫為三條;AC-5/AC-16 向量重做。
- **F3-3**:AC-6 新向量斷言②b 與③「不應出現矛盾」,但 Core Rules #5 步驟②結語**明文允許**落差並定案「恆以③為準」—— AC 與它要驗證的規則直接對撞,且落差分支零向量。已限縮原向量 + 新增落差向量。
- **F3-7**:§6 全手把清單兩輪內漏兩項,而其行內註記聲稱「已於 §6.1 一併改為結構性修法」—— 結構性修法實際只套用到 §6.1(僅漂移一次那份),漂移兩次的 §6 反而仍是裸列舉。已改為原則陳述,移除不實宣稱。
- **P-1**:Edge Cases 佔位釋放 + AC-7(c) 的「自陣亡起…不遮蔽視線」句式暗示陣亡解除了視線阻擋,與 Core Rules #4(B-5)矛盾。已拆為兩句並記錄舊措辭缺陷。
- **P-2**:AC-3 缺 `max < min`(如 `(3,2)`)向量。已補。

### 專家分歧(已呈報使用者、已裁決)

`godot-specialist` 主張「`|dx|=|dy|` 是唯一產生角點歧義的情形,規則不殘缺」;`qa-lead` 主張 `(2,2)` 與 `(1,1)` 不同型。主 session 驗算判定兩者皆不完整,`(1,3)` 為可獨立重現的反例。使用者裁示採用此驗算,不另派 `systems-designer` 複驗。

---

## 落地修訂範圍(逐檔)

- **`design/gdd/tactical-combat-system.md`**:新增 Core Rules #10 總則;Edge Cases 穿角條款重寫為三條、佔位釋放條款拆分視線句、預判/疊加圖兩條標為總則具名實例;Formulas 公式四新增多敵聯集定義 + 回傳兩切面;UI Requirements §1/§1a 補即時性指標、§1a 補並存性義務、§6 改原則陳述;Visual/Audio §6.1「三態」改「各個可觀測值」;Core Rules #5 補 `duplicate_deep()` 區分;新增 **AC-22** 含 7 條向量 + 測試撰寫提醒;AC-3/5/6/7/16 向量修訂;Dependencies #10 列補約束;Open Questions OQ-16/18 追加;標頭全面改寫(含收斂狀態、Phase 5a-ter 檢查結果)。
- **`design/gdd/systems-index.md`**:Cross-System Obligations Registry 新增一列(Core Rules #10 對戰鬥 HUD #10 的查詢介面義務 + 疊加圖並存性義務)。
- **`design/gdd/reviews/tactical-combat-system-review-log.md`**:**新建**。第一、二輪先前從未寫入 review-log(僅存在於 GDD 標頭與 commit message),此缺口本身是第三輪 Phase 4 的發現之一。三輪記錄皆已登錄(一、二輪為回溯登錄)。

## Grep 自核 pass 結果

檢查 `正對角穿角`、`正對角(穿角)`、`|dx| = |dy|`、`單位當前狀態三態`、`不遮蔽視線`、`duplicate(true)`、AC 編號、Core Rules 計數。所有殘留命中經逐一查核皆屬**刻意保留**(修法史引述舊措辭以說明缺陷、`Dictionary` 仍正確適用 `.duplicate(true)`、標頭對第二輪的歷史描述)。`.claude/agent-memory/ux-designer/` 一處舊「三態」措辭屬 agent 記憶的歷史紀錄,非規範文件,不修。**無未同步的規範性殘留。**

---

## 下一步

1. **尚未 commit** —— 三個檔案待提交(2 改 1 新)。
2. **第四輪 `/design-review` 應於全新 session 執行,並建議升級為完整模式** —— 依 Phase 0b 升級門檻,本輪 7 項 BLOCKING-NOW 全為設計內容缺陷,已觸發升級條件;第三輪因使用者裁示與 session 額度限制維持三位專家,升級延至第四輪。第四輪應特別覆核新增的 Core Rules #10 總則與 AC-22 是否與既有 AC-11/AC-20 產生重疊或縫隙。
3. **收斂狀態**:連續零 BLOCKING-NOW 輪數 = **0**(第一輪 6、第二輪 5、第三輪 7,三輪皆 body-scoped)。距 APPROVED 尚需**連續兩輪** body-scoped 零 BLOCKING-NOW。
4. 本系統仍為 **Designed, 尚未 Approved**,不得移交 `/create-architecture`。

## 仍未處理(非本輪範圍)

- **OQ-2**(`player_baseline_stat` 全專案無擁有者)與 **OQ-10**(無「不可通行」地形層級)—— 文件自陳的兩項下游阻擋項,須在 `/create-architecture` 前指派/裁決。
- `systems-index.md` 標頭部分歷史段落仍有行號式自我引用(如「見上方第 150 列」),與 `.claude/rules/design-docs.md` 的「禁止行號自我引用」規則相衝;本輪未逐一追蹤修正(非本輪覆核範圍)。
