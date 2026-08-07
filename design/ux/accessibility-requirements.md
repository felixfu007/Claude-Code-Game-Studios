# Accessibility Requirements:《弈緣》(暫定)

> **Status**: Draft(最小骨架,2026-08-06 建立——回應 `cursor-highlight-state.md` 持久遺留帳本 L10,連續 6 輪轉交聲明孤兒化後正式建立)
> **Author**: ux-designer
> **Last Updated**: 2026-08-06
> **Accessibility Tier Target**: 待定(見下方 Open Questions)
> **Platform(s)**: PC、Console(見 `.claude/docs/technical-preferences.md`)
> **External Standards Targeted**: 待定
> **Accessibility Consultant**: None engaged
> **Linked Documents**: `design/gdd/systems-index.md`、`design/gdd/cursor-highlight-state.md`

> **建立背景**:本文件先前僅以口頭/review log 形式被多次轉交(`cursor-highlight-state.md` 第六輪起),但檔案本身從未建立,已連續 6 輪(第六~十一輪)構成孤兒義務。本次為第十一輪 `/design-review` 使用者裁決要求的**最小骨架**,目的是讓帳本政策恢復效力、讓已承諾的覆寫點有一個真實存在的落地位置——不是完整的無障礙規格書。多數欄位維持 `Not Started`/待定,詳細內容(Tier 選擇的理由、完整的視覺/認知/聽覺無障礙矩陣)留待 Technical Setup 階段依範本 `.claude/docs/templates/accessibility-requirements.md` 正式擴充。

---

## Accessibility Tier Definition

**Target Tier**: 待定——目前僅有單一系統(`cursor-highlight-state.md`)明文承認覆寫點,尚無足夠的全專案系統盤點可據以選擇 Tier。

**Rationale**: 待補——需待更多系統(尤其戰棋移動與交戰系統、支援對話系統)完成設計後,才能評估動作類與認知類無障礙需求的實際範圍。

---

## Motor Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| 滑鼠奪回權威的空間門檻可調整性(`mouse_reclaim_threshold_px_by_surface_type`) | 待定 | `cursor-highlight-state.md` Core Rules #3 | Not Started | 該文件已明文將此 Tuning Knob 登記為本無障礙需求的覆寫點(見該文件 Tuning Knobs「無障礙覆寫點的明文承認」)——若本文件日後定案需要玩家可調整的奪權門檻,落地位置即為此旋鈕,不需修改 `cursor-highlight-state.md` 規則本體。實際是否需要可調整性、調整範圍為何,待此處定案。 |
| 類比搖桿死區可調整性(反方向零門檻豁免所依賴的死區設定) | 待定 | `cursor-highlight-state.md` Core Rules #3「反方向」 | Not Started | 同上,`cursor-highlight-state.md` 已登記此為第二個覆寫點。搖桿死區設定是否足以應對硬體老化/校準問題尚未經真實硬體測試(見該文件 Open Questions)。 |
| 持續按住方向鍵/搖桿導致滑鼠奪權鎖死的殘留風險 | 待定 | `cursor-highlight-state.md` Core Rules #3 觸發點 (d) | Not Started | 第十輪 spike 證實此風險成立,第十一輪對抗性審查判定同日嘗試的修法(限縮否決資格 + 保險上限)不成立並撤回,目前登記為已知殘留風險。此問題與運動無障礙高度相關(例如切換式輔助裝置模擬按鍵的持續觸發模式)——本文件日後定案動作無障礙需求時,應將此案例列為具體參照情境,避免未來的修法方向與無障礙需求本身脫節。 |
| 全套輸入重新綁定(remapping) | Standard(範本建議) | 全域 | Not Started | 待「輸入設定/重新綁定」系統納入 `systems-index.md` 後定案(該系統目前尚未列出,見 `cursor-highlight-state.md` Open Questions)。 |
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
| 本專案的 Accessibility Tier Target 該設為哪一級,依據為何 | ux-designer / producer | Technical Setup 階段 | Unresolved |
| `mouse_reclaim_threshold_px_by_surface_type` 與搖桿死區是否需要玩家可調整,調整範圍為何 | ux-designer | 垂直切片階段(與 `cursor-highlight-state.md` 校準工作同批) | Unresolved |
| 「輸入設定/重新綁定」系統是否需要新增至 `systems-index.md` | producer | 下次系統盤點時 | Unresolved |

---

## External Resources

見 `.claude/docs/templates/accessibility-requirements.md` 完整清單(WCAG 2.1、Game Accessibility Guidelines、AbleGamers Player Panel、XAG、PlayStation Accessibility Guidelines 等)。
