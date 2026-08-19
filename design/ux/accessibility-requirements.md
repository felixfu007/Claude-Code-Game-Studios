# Accessibility Requirements:《弈緣》(暫定)

> **Status**: **Tier Committed**(2026-08-19 使用者裁決;此前為 2026-08-06 建立的最小骨架)
> **Author**: ux-designer(骨架)/ 2026-08-19 Tier 定案
> **Last Updated**: 2026-08-19
> **Accessibility Tier Target**: **Standard**(定義見 `.claude/docs/templates/accessibility-requirements.md`)
> **Platform(s)**: PC、Console(見 `.claude/docs/technical-preferences.md`)
> **External Standards Targeted**: 待定
> **Accessibility Consultant**: None engaged
> **Linked Documents**: `design/gdd/systems-index.md`、`design/gdd/cursor-highlight-state.md`

> **建立背景**:本文件先前僅以口頭/review log 形式被多次轉交(`cursor-highlight-state.md` 第六輪起),但檔案本身從未建立,已連續 6 輪(第六~十一輪)構成孤兒義務。本次為第十一輪 `/design-review` 使用者裁決要求的**最小骨架**,目的是讓帳本政策恢復效力、讓已承諾的覆寫點有一個真實存在的落地位置——不是完整的無障礙規格書。多數欄位維持 `Not Started`/待定,詳細內容(Tier 選擇的理由、完整的視覺/認知/聽覺無障礙矩陣)留待 Technical Setup 階段依範本 `.claude/docs/templates/accessibility-requirements.md` 正式擴充。

---

## Accessibility Tier Definition

**Target Tier**: **Standard**(2026-08-19 使用者裁決)

**Standard 的核心承諾**(引自範本):Basic 全部,加上——**全平台完整輸入重新綁定、字幕含說話者標示、字級可調、至少一種色盲模式、不存在無法延長或關閉的限時輸入**。

**Rationale**:

1. **本作的類型結構已經消去最嚴重的動作類障礙。** 回合制戰棋沒有即時反應要求,不存在動作遊戲常見的 fast-twitch 門檻。動作類需求因此集中在**輸入方式**(重新綁定、單手操作)而非**反應速度**,而重新綁定正是 Standard 的基準項。
2. **但對話與數值密度高,視覺與認知障礙才是真正的風險面。** 好感度數值池、支援對話、關係迷你地圖都是**讀字與讀關係圖**的介面。字級可調與色盲模式在本作不是加分項,是可用性的前提。
3. **專案早已承諾的項目實際上就落在 Standard 這一層。** `.claude/docs/technical-preferences.md` 明訂「全手把對等、主機無游標、**禁止 hover-only 互動**」;`game-concept.md` 明訂好感度連線「不得僅靠色彩區分」;`cursor-highlight-state.md` 承諾三態視覺與全域裝置指示皆不僅依賴色彩,並已登記兩個無障礙覆寫點。**定案 Standard 不是新增義務,是把已散落各處的承諾收斂成一個可被檢查的層級。**
4. **降到 Basic 會與既有文件直接矛盾。** Basic 不含輸入重新綁定與色盲模式,而這兩項在上述三份文件裡都已經是明文承諾——選 Basic 等於讓 Tier 宣告低於實際承諾,比不宣告更糟。
5. **升到 Comprehensive 目前沒有支撐。** 螢幕閱讀器選單支援需要平台 API 整合與 UI 架構層的投入,而本專案 `src/` 為空、無專職無障礙工程師、`Accessibility Consultant: None engaged`。宣告一個做不到的層級會讓這份文件失去閘門價值。

### 本 Tier 對現有設計造成的兩項具體約束(定案的實際後果)

定案 Tier 的意義不在填標籤,而在它**立刻對已凍結/已定案的設計產生約束**。逐項登記:

| 約束 | 來源 | 現況 | 影響 |
|---|---|---|---|
| **「不存在無法延長或關閉的限時輸入」** | Standard 基準項 | `game-concept.md` 第三輪 creative-director 裁決:好感度對話卡牌**發牌節奏固定**。「固定節奏」是否構成限時輸入**尚未釐清** | ⚠️ **待裁決**。若該節奏會迫使玩家在時限內反應,即與本 Tier 直接衝突,須提供延長或關閉選項;若只是演出節奏、不含輸入時限,則不衝突。**此項須在支援對話系統設計時明確回答,不得預設為不衝突。** |
| **全平台完整輸入重新綁定** | Standard 基準項 | `cursor-highlight-state.md` 第五輪明文**排除**玩家執行期重新綁定按鍵對本系統的影響;而「輸入設定/重新綁定」系統**尚未列入 `systems-index.md`** | ⚠️ 本 Tier 使該系統從「可選」變為**必要**。`systems-index.md` 的下一次盤點必須納入它。游標系統的排除聲明不衝突(它排除的是重新綁定對游標邏輯的影響,不是排除重新綁定功能本身),但兩者的交界須在該系統設計時檢查 |

> **第三項相關但不構成新約束的登記**:滑鼠奪權子機制的 E1 缺陷(類比搖桿持續按住造成永久鎖死,spike 實測 100% 可重現)**高度命中動作無障礙**——切換式輔助裝置模擬按鍵的持續觸發模式正好會踩中它。該子機制已由使用者裁決凍結、待手把硬體。**本 Tier 不解凍它,但明文登記:重啟該子機制的重新設計時,必須把本 Tier 的動作無障礙要求列為輸入條件之一**,避免修法方向再次與無障礙需求脫節(這正是本文件建立的原始理由)。

**明文超出 Tier 基準的項目**:目前無。

**明文排除的項目**:螢幕閱讀器選單支援、HUD 元件位置自訂、難度輔助模式、第三方無障礙稽核(皆屬 Comprehensive/Exemplary,見上方 Rationale 第 5 點)。若日後取得專職資源可重新評估。

---

## Motor Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| 滑鼠奪回權威的空間門檻可調整性(`mouse_reclaim_threshold_px_by_surface_type`) | 待定 | `cursor-highlight-state.md` Core Rules #3 | Not Started | 該文件已明文將此 Tuning Knob 登記為本無障礙需求的覆寫點(見該文件 Tuning Knobs「無障礙覆寫點的明文承認」)——若本文件日後定案需要玩家可調整的奪權門檻,落地位置即為此旋鈕,不需修改 `cursor-highlight-state.md` 規則本體。實際是否需要可調整性、調整範圍為何,待此處定案。 |
| 類比搖桿死區可調整性(反方向零門檻豁免所依賴的死區設定) | 待定 | `cursor-highlight-state.md` Core Rules #3「反方向」 | Not Started | 同上,`cursor-highlight-state.md` 已登記此為第二個覆寫點。搖桿死區設定是否足以應對硬體老化/校準問題尚未經真實硬體測試(見該文件 Open Questions)。 |
| 持續按住方向鍵/搖桿導致滑鼠奪權鎖死的殘留風險 | 待定 | `cursor-highlight-state.md` Core Rules #3 觸發點 (d) | Not Started | 第十輪 spike 證實此風險成立,第十一輪對抗性審查判定同日嘗試的修法(限縮否決資格 + 保險上限)不成立並撤回,目前登記為已知殘留風險。此問題與運動無障礙高度相關(例如切換式輔助裝置模擬按鍵的持續觸發模式)——本文件日後定案動作無障礙需求時,應將此案例列為具體參照情境,避免未來的修法方向與無障礙需求本身脫節。 |
| 全套輸入重新綁定(remapping) | **Standard(已定案,2026-08-19)** | 全域 | Not Started | **本專案 Tier 定為 Standard,此項因而由「範本建議」升為硬性要求。** 「輸入設定/重新綁定」系統**尚未列入 `systems-index.md`**——下一次系統盤點必須納入,見上方「本 Tier 對現有設計造成的兩項具體約束」。 |
| 其餘動作無障礙項目(單手模式、hold-to-toggle、瞄準輔助等) | — | — | Not Started | 待戰棋移動與交戰系統等核心玩法系統設計後補齊。 |

---

## Visual / Cognitive / Auditory Accessibility

Not Started——待更多系統完成設計後依範本 `.claude/docs/templates/accessibility-requirements.md` 補齊各節矩陣。已知會涉及的項目(依 `cursor-highlight-state.md` 既有登記):
- 三態視覺(一般高亮/待重新解析/滑鼠奪權漸進回饋)與全域裝置狀態指示元件皆已在該文件承諾「不僅依賴色彩」(見該文件 Visual/Audio Requirements),色盲友善audit 待此處正式收錄。

---

## Per-Feature Accessibility Matrix

| System | Visual Concerns | Motor Concerns | Cognitive Concerns | Auditory Concerns | Addressed | Notes |
|--------|----------------|---------------|-------------------|------------------|-----------|-------|
| 單一游標/高亮狀態系統 | 三態視覺色盲友善已承諾(不僅依賴色彩) | 奪權門檻/死區覆寫點已登記;持續按住鎖死殘留風險待處理 | — | — | Partial | 見上方 Motor Accessibility 表 |
| [其餘系統待各自 GDD 完成後補列] | | | | | Not Started | |

---

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| ~~本專案的 Accessibility Tier Target 該設為哪一級,依據為何~~ | ux-designer / producer | Technical Setup 階段 | **✅ Resolved 2026-08-19 —— Standard**,理由見上方 Accessibility Tier Definition 五點 |
| **好感度對話卡牌的「固定發牌節奏」是否構成 Standard 禁止的限時輸入** | game-designer / creative-director | 支援對話系統設計時 | **Unresolved(2026-08-19 Tier 定案時新增)**——不得預設為不衝突 |
| **「輸入設定/重新綁定」系統納入 `systems-index.md`** —— Tier 定案後由可選變為必要 | producer | 下次系統盤點 | **Unresolved(2026-08-19 由「是否需要」改為「何時納入」)** |
| `mouse_reclaim_threshold_px_by_surface_type` 與搖桿死區是否需要玩家可調整,調整範圍為何 | ux-designer | 垂直切片階段(與 `cursor-highlight-state.md` 校準工作同批) | Unresolved |
| 「輸入設定/重新綁定」系統是否需要新增至 `systems-index.md` | producer | 下次系統盤點時 | Unresolved |

---

## External Resources

見 `.claude/docs/templates/accessibility-requirements.md` 完整清單(WCAG 2.1、Game Accessibility Guidelines、AbleGamers Player Panel、XAG、PlayStation Accessibility Guidelines 等)。
