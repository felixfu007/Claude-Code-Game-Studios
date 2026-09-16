# Story U-014:確認面板 S3(逐欄拆解、配對回顯、箭頭版面;不含數值)

> **Epic**:卡牌介面、戰鬥選單與取消鍵(`production/epics/card-play-interface/EPIC.md`)
> **型別**:UI
> **狀態**:📋 Ready
> **估時**:M
> **依賴**:U-013(選作用對象 S2/S2p/S2q)
> **波次**:波 5(與 U-015 真平行——本 story 寫 `card_confirm_panel.gd`(新),U-015 寫 `hand_bar.gd` + `battle_screen.gd`;⚠️ 前置不同,本 story 需 U-013,U-015 需 U-012)

## Context

- **UX 規格**:`design/ux/skill-card-play.md`(AC-U1、AC-U5、AC-U7、AC-U11、AC-U13〔部分〕、AC-U14〔部分〕,「確認面板欄位」小節)
- **權威 ADR**:ADR-0001(戰棋查詢原子性,**Accepted**)——確認是本流程唯一的權威寫入路徑(路徑 ⑥,`skill-card-system.md` Core Rules 四第 4 步)
- **Engine**:Godot 4.7.1

## 本 story 決定的原始碼目錄路徑

新檔:`src/ui/battle/card_confirm_panel.gd`(+ 對應 `.tscn`)。

## 目標

建立確認面板(S3),逐欄拆解甲類/丙類的效果,並在確認時呼叫既有的 `CardPlaySession.confirm()`——本 story 不重新實作任何寫入邏輯或去重保護,兩者都已由邏輯層交付。

## 本 story 必須讀而非重寫的既有邏輯層

`card_play_session.gd:271` 的 `confirm() -> bool`:

- 只在 `_step == Step.CONFIRMING` 時生效,否則直接回傳 `false`、不改變任何狀態。
- 甲類:對目標呼叫 `target.add_modifier(CardModifier.new(...))`。
- 丙類:呼叫 `PermanentAffinityWriteRules.play(card, target_a, target_b, links, write_port)`;若埠拒絕(`Rejection != NONE`),回傳 `false` 且**不**把卡片移入已用牌堆,`_step` 停在 `CONFIRMING` 不變(呼叫端仍可 `cancel()`)。
- 成功時內部呼叫 `_reset_to_closed()`,把 `_step` 設回 `CLOSED`。

🔴 **AC-U11(同幀鍵盤+手把各送一次確認只提交一次)已由這個狀態轉換本身結構性保證,不需要本 story 另建去重旗標**——`confirm()` 的類別文件註解逐字寫明:「a second call made immediately after a successful one cannot re-apply anything, because a successful call always leaves `Step.CLOSED` behind before returning — the very next call finds `_step` already `Step.CLOSED` … and returns `false` at the first line」。本 story 的鍵盤 `_input` 與手把 `_input` 兩條分派路徑都呼叫同一個 `session.confirm()` 即可,**不要再疊加一層自己的旗標**——那反而製造出「兩份判斷,可能漂移」的風險,與 `skill-card-play.md` 原文建議的「確認後立即關閉手牌介面並清空選取」是同一件事的兩種寫法,選用既有結構保證的這一種。

## Implementation Notes

1. **甲類確認面板欄位**(`skill-card-play.md`「確認面板欄位」小節,逐欄轉錄):卡名與牌面文字、作用對象、`Δatk`/`Δdef`(帶號,`0` 仍顯示)、存續回合 `r`(數字,不是 Z4 的點——本面板是介面層,無 6×6px 限制)、該對象生效中的既有修正逐條(來源、帶號量值、剩餘回合,同 Z5,讀 `Unit.active_modifiers()`)、合併後有效值(`ATK_eff`/`DEF_eff`)。🔴 **合併後有效值不得取代逐條那一列**——GDD UI Requirements #7 明文禁止只給合併值,本面板兩者並列。

2. **丙類確認面板欄位**(同小節):卡名與牌面文字、作用對象(配對雙方姓名,回顯玩家在 S2p/S2q 的選取——**不得從卡片欄位讀**,`affinity_character_a`/`_b` 只是牌面敘事,機制上不讀,見 U-013 依賴的既有邏輯)、「永久」不可逆警示(文字+圖示)、好感度數值(「現值 → 打完後」箭頭,例 `+3 → +4`)、敘事影響(一句定性文字,零數字)。

3. 🔴 **好感度箭頭是合規的必要條件,不是排版偏好**——`skill-card-play.md` 逐字:「換一種做法——現值與結果值分放兩欄、無箭頭關聯——就會落回 #4 明文禁止的形狀」。AC-U14 的後半句直接要求這個測試對「兩欄並排、無箭頭」的版本必須轉紅,見下方 Test Evidence。

4. 🔴 **`combat_strength_read` 在 `src/` 尚未實作(本 story 自己查證的事實,已核對 `grep -rn "combat_strength_read" src/` 零命中)**——見下方 Out of Scope 對 AC-U13/AC-U14「部分涵蓋」成因的完整交代,不要在這裡另外處理。

5. **AC-U1 傷害預覽更新機制**:甲類確認成功後,`target.add_modifier()` 直接改變該單位的 `active_modifiers()` 內容,而 `Unit.effective_atk()`/`effective_def()` 是每次查詢即時計算、不快取——故既有的傷害預覽 HUD(`BattleState.preview_damage()`)下一次查詢就會自動反映新值,**本 story 不需要自己搬運或快取這個數字**,只需要在 `confirm()` 成功後觸發既有畫面刷新路徑(參照 `battle_screen.gd:728` 的 `_end_faction_phase_pressed()` 在寫入後呼叫 `_refresh_view()` 的既有模式),讓 HUD 重新查詢一次。⚠️ **`commit_authoritative_change()` 目前只是 `battle_state.gd` 裡的一句文件註解,尚未有函式本體或 `combat_state_version` 遞增機制真正落地**——ADR-0001 把「卡牌打出第 4 步確認完成」列為應遞增版本號的路徑 ⑥,但這條遞增today不存在;本 story 呼叫 `session.confirm()` 後刷新畫面即可達成 AC-U1 的可觀測效果,不必等待也不必自行補上版本號遞增機制(那屬 ADR-0001 機制一的落地範圍,非本 story 職責)。

6. **AC-U5 全手把路徑**:確認 = `battle_confirm`(A),取消 = `battle_cancel`(B),兩者在 S3 都必須可達,不得有僅滑鼠可達的操作(`P-I2` 無例外)。

7. **AC-U7**:確認前取消(呼叫 `session.cancel()`)→ 好感度記錄筆數不變、無任何甲類修正產生——這是 `cancel()` 從 `CONFIRMING` 退回時清空 `_selected_target_a`/`_b` 而非呼叫 `confirm()` 的直接後果,本 story 只需確保取消鍵在 S3 呼叫的是 `cancel()` 而非任何自製的「假取消」路徑。

## Acceptance Criteria

*以下為 `design/ux/skill-card-play.md` 的條文原文轉錄,未改寫:*

- [ ] **AC-U1**:傷害預覽顯示 `4` → 打出 `ATK +3` 的甲類 → 畫面上的數字變為 `7`,不得殘留 `4`;且該數字取自與結算同一份預判查詢,不得由測試自算(Integration,BLOCKING)
- [ ] **AC-U5**:全程不接滑鼠、只用手把 → 完成「開手牌 → 選牌 → 選對象 → 確認」與「開手牌 → 取消」兩條完整路徑(UI,BLOCKING,`P-I2` 無例外)
- [ ] **AC-U7**:選定丙類 → 選定配對 → 在確認前取消 → 好感度記錄筆數不變、無任何甲類修正產生(Integration,BLOCKING)
- [ ] **AC-U11**:同一幀鍵盤 `Enter` 與手把 `A` 各送一次確認 → 只提交一次(好感度記錄 `+1` 而非 `+2`)(Integration,BLOCKING)
- [ ] **AC-U13**:選定一張丙類 → 於棋盤上選定甲、乙兩個特定棋子 → 確認面板顯示的兩個姓名與甲、乙一致;取消後改選另一對(丙、丁)→ 面板同步顯示丙、丁,不殘留前一對(Integration,BLOCKING)⚠️ **部分**——姓名回顯做得到,面板端到端受 UX-13 阻擋(見 Out of Scope)
- [ ] **AC-U14**:丙類確認面板開啟 → 該配對的好感度數值恰好出現一次,以「現值 → 打完後」箭頭呈現(例:`+3 → +4`);把面板改成兩欄並排、無箭頭關聯的版本 → 本測試必須轉紅(UI,BLOCKING)⚠️ **部分**——箭頭版面做得到,數值做不到(見 Out of Scope)

## Test Evidence

**型別**:UI
**測試檔 / 證據**:`tests/integration/ui/card_confirm_panel_test.gd` + `production/qa/evidence/story-u014-confirm-panel-evidence.md`

預期涵蓋:

- `test_confirm_panel_甲類_shows_delta_atk_def_with_sign_and_zero_visible`
- `test_confirm_panel_甲類_shows_per_entry_modifiers_alongside_merged_effective_value`(UI Requirements #7,兩者並列)
- `test_confirm_panel_丙類_reflects_player_selected_pair_not_card_fields`(AC-U13 前半)
- `test_confirm_panel_丙類_pair_updates_after_reselecting_without_residue`(AC-U13 後半)
- `test_second_confirm_same_frame_applies_only_once`(AC-U11,驗證依賴既有 `Step.CLOSED` 結構保證,不驗證新旗標)
- `test_cancel_before_confirm_leaves_zero_new_records`(AC-U7)
- `test_gamepad_only_path_completes_full_and_cancel_flows`(AC-U5)
- `test_confirm_panel_arrow_layout_required_two_column_no_arrow_variant_must_fail`(AC-U14 鑑別力測試——刻意實作「兩欄並排、無箭頭」的版本並斷言測試轉紅)
- `test_damage_preview_reflects_new_effective_atk_after_confirm`(AC-U1,呼叫既有 `BattleState.preview_damage()`,不自行計算)

## Out of Scope

- 🔴 **丙類確認面板的好感度數值本身(AC-U13/AC-U14「打完後」數值那一半)無法端到端驗證。** 本 story 自己查證的事實:`grep -rn "combat_strength_read" src/` **零命中**——`combat_strength_read`(`design/gdd/affinity-data-pool.md` 公式一,回傳「這一對的帶正負號目前極性與強度」)在 `src/` 完全沒有實作。`skill-card-play.md` 已把這條登記為 **UX-13**,擁有者是 `affinity-data-pool` epic 的 **S-007**。「打完後」值是否需要一個預判版查詢也尚未定案(同一則 UX-13)。**本 story 交付的是箭頭版面本身(空欄位 + 提示文案),不是數值** —— 依 `skill-card-play.md` 的「查無資料時的處理」表:UX-13 未關閉前該欄位**留白 + 同一句提示,不得顯示 `0` 或省略欄位**(省略會讓 #4 的「唯一數值」承諾無從檢查)。**下一個人不需要重新查一次 `grep -rn "combat_strength_read" src/`,結果已經在這裡。**
- **選作用對象 S2/S2p/S2q、合法目標高亮、跳轉鍵**——屬 U-013(已交付,本 story 從其後接續)。
- **強制棄牌 S4**——屬 U-015。
- **`PermanentAffinityWriteRules.play()` 與 `AffinityWritePort` 的邏輯本身**——已由既有 `card_play_session.gd` 交付,本 story 不重寫;寫入埠今天接的是 `NullAffinityWritePort`(收下即丟棄的空殼),即使本 story 做完,玩家打丙類卡看到完整四步流程但好感度不會真的改變(EPIC.md 限制第 2 條,`affinity-data-pool` epic 的 S-008/S-009 負責)。
- **卡面美術**——UX-3,`art-director` + `/art-bible`。
