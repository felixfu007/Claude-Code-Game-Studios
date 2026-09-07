# Story 011（原生游標隱藏 + 自繪載體）測試證據

**Story Type**：Visual/Feel
**日期**：2026-09-07
**執行者**：godot-specialist

## 自動化測試涵蓋

`tests/unit/cursor/self_drawn_reclaim_cursor_test.gd`（8 條）與
`tests/unit/cursor/native_pointer_visibility_arbiter_test.gd`（8 條），headless 可跑。
逐條 AC 對應與涵蓋範圍(含部分涵蓋的理由)見兩檔各自的檔頭註解與本 story 最終回報。

## AC-28c / AC-41 / AC-41b（真的開視窗擷取畫面,已完成）

**這三條的驗證方式在 GDD 原文即為「Visual/Feel 類證據,screenshot + lead sign-off,
ADVISORY 等級」**,不是自動化測試的阻擋範圍(但本 story 額外補了自動化測試作為輔助
證據,見上方涵蓋清單 —— `test_ac28c_...`、`test_ac41_...`、`test_ac41b_...`)。

### 擷取方式

`prototypes/story-011-evidence-capture-2026-09-07/EvidenceDriver.tscn`（拋棄式驅動場景,
直接載入正式場景 `res://src/ui/battle/BattleScreen.tscn` 本體,不是複本),以

```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --path . prototypes/story-011-evidence-capture-2026-09-07/EvidenceDriver.tscn
```

執行(真實 GPU、非 headless)。

🔴 **為何 driver 自己建一份 `CursorState`/`ThresholdMouseReclaimPolicy`,不是直接驅動
`CursorStateHost` Autoload 那份**:ADR-0005 機制六「裝置權威仲裁對真實輸入事件的自動
逐幀呼叫」是 Story 005 的 SEAM(`cursor_state.gd` 的 `arbitrate_device_authority()`),
**目前是空的**——本專案今天沒有任何程式碼會在滑鼠真的移動時自動呼叫
`MouseReclaimPolicy.evaluate()`。伸手進 Autoload 私有的 `_state` 去驅動它的
`_reclaim`,會直接命中已登記的禁令 `external_access_to_cursor_reclaim_instance`
(`docs/registry/architecture.yaml:2056`)——即使 `prototypes/` 不受 `src/` 規範約束,
這裡仍主動遵守該紀律,因為繞過它不能證明本 story 真正交付的東西。**driver 改為自建一份
獨立的 `CursorState` + `ThresholdMouseReclaimPolicy`,搭配與正式程式碼完全相同的
`SelfDrawnReclaimCursor` / `NativePointerVisibilityArbiter` 兩個類別**,手動以
`Input.warp_mouse()` 真實移動 OS 滑鼠、並在自己持有的 `policy` 上呼叫 `evaluate()` ——
這是 Story 005 落地前,唯一誠實展示本 story 呈現層行為的做法。真正的 `CursorStateHost`
Autoload 全程仍在背景執行,它自己的自繪游標因為沒有任何東西驅動它的 policy,`modulate.a`
永遠是 0(不可見),它自己的 hover 仲裁器也各自獨立判定為 HIDDEN(裝置權威從未離開
`UNINITIALIZED`,不是 `MOUSE`)——兩者不會與 driver 自建的那一份互相搶奪
`Input.mouse_mode` 的寫入結果,因為判定結果剛好一致。

三張擷圖對應 `reclaim_progress` 的三個階段(門檻 80px,滑鼠自 `(960,540)` 起算):

| 檔案 | reclaim_progress | 滑鼠位移 |
|---|---|---|
| `story011-native-cursor-suppression-start-2026-09-07.png` | 0.0 | 0px(起點) |
| `story011-native-cursor-suppression-partial-2026-09-07.png` | 0.4 | 32px(80px 的 40%) |
| `story011-native-cursor-suppression-full-2026-09-07.png` | 1.0 | 80px(達門檻) |

### 機械檢查(`.claude/docs/coding-standards.md` Screenshot Evidence Rules)

三張圖擷取時**當場**驗證,不通過就不寫檔(`evidence_driver.gd` 的 `_capture_and_verify()`)：

| 檢查項 | 門檻 | start | partial | full |
|---|---|---|---|---|
| 擷圖尺寸 = 視窗尺寸 | 1920×1080 | **1920×1080** ✅ | **1920×1080** ✅ | **1920×1080** ✅ |
| 12 點抽樣相異色數 | ≥ 3 | 4 ✅ | 4 ✅ | 4 ✅ |
| 主導色佔比(每 4px 全圖抽樣) | ≤ 80% | 43.06% ✅ | 43.06% ✅ | 43.06% ✅ |

逐字輸出：`prototypes/story-011-evidence-capture-2026-09-07/run_output.txt`

⚠️ **像素整數縮放格線完整性(規則第 4 條)未量測**——本次擷圖的驗證重點是游標系統本身
的行為(消失/出現/透明度漸變),不是世界層縮放正確性(該項已由 Story 001 的
`prototypes/story-001-manual-scaling-verification-2026-09-04/` 獨立驗證,本次擷圖沿用
同一份 `BattleScreen.tscn` 與 `world_viewport_scaler.gd`,未改動縮放邏輯)。誠實登記為
未做,不假裝已涵蓋。

### 人眼確認(規則第 5 條,機械檢查不能取代)——三件事逐項確認

**已由本 agent 用 Read 工具開三張圖檢視**：

1. **系統原生游標真的消失了**——三張圖畫面中央都看不到任何 OS 系統游標圖案殘留
   (箭頭/沙漏等)。⚠️ **這項機械檢查與肉眼screenshot都有結構性局限**：OS 硬體游標
   通常由作業系統合成層疊加在應用程式畫面之上,`get_viewport().get_texture().get_image()`
   擷取的是應用程式自己畫的內容,**本來就不包含 OS 游標疊加層,不論
   `Input.mouse_mode` 設什麼值**——所以這張截圖「看不到系統游標」不能單獨當作
   「系統游標真的被隱藏」的證據(即使沒隱藏,截圖同樣看不到它)。
   🔴 **本項的實際證據來自 driver 執行期間印出的真實引擎數值**(見
   `run_output.txt`,非截圖):三個階段 `Input.mouse_mode` 皆讀回 `1`
   (`Input.MOUSE_MODE_HIDDEN`)——這是在**真實視窗、非 headless** 的引擎行程裡讀到的
   真實值(headless 下這個讀值不可信,見下方「引擎版本陷阱」段落),證明
   `NativePointerVisibilityArbiter` 真的把 OS 游標設成隱藏,而不只是「畫面上剛好沒有
   東西」。若使用者本人在真實視窗前移動滑鼠,肉眼會看到系統游標圖案消失——這件事
   `production/qa/evidence/` 的靜態截圖無法呈現,只有即時操作能看到。
2. **自繪的游標真的被畫出來了**——`start.png` 中央(座標約 960,540)看不到任何點,
   `partial.png` 同一位置(實際落點偏右約 32px)有一個**淡灰色、半透明**的小圓點,
   `full.png` 同一位置(偏右 80px)有一個**實心白色、不透明**的小圓點。三張圖並列比對,
   圓點確實隨 `reclaim_progress` 從無到有、由淡轉濃。
3. **濃淡真的隨滑鼠移動變化**——見上一項的三段式比對:0.0 進度時 alpha=0(不可見)、
   0.4 進度時 alpha≈0.4(淡灰、半透明)、1.0 進度時 alpha=1.0(全白、不透明)。
   三張圖對應的 `reclaim_progress` 數值(`0.0` / `0.4` / `1.0`)皆由 driver 逐字印出,
   與截圖內容一致。

## AC-36 / AC-48 / AC-49 —— 登記為未涵蓋,待美術規範(不阻擋)

依 `coding-standards.md` 證據等級表,三條原文皆為「Visual/Feel 類證據,
screenshot + lead sign-off,ADVISORY 等級」,**ADVISORY 不是阻擋級**。且三條要比較的
視覺(「一般高亮」「待重新解析」)**沒有任何圖形規格**——`/art-bible` 從未執行,
`design/art/` 對這兩個詞零命中。本 story 的自繪替代游標形狀(`self_drawn_reclaim_cursor.gd`
的 `_RADIUS_PX` 純白圓點)是**本 story 自己的工程佔位**,不是設計裁決,因此無法據此
判定與其他視覺元素的可辨識性。**明文登記為待美術規範,不自行發明視覺規格去湊。**

## 已知未涵蓋

- AC-19 / AC-38：部分涵蓋(structural partial),完整行為依賴 Story 005(裝置權威仲裁
  SEAM)與尚未建置的點擊處理呼叫方,見兩份測試檔各自的檔頭「Scope narrowing」說明。
- AC-36 / AC-48 / AC-49：見上方,登記為待美術規範。
- 像素整數縮放格線完整性未對本次三張圖執行(理由見上方)。
- 沒有測試真人手把/類比搖桿路徑(本 story 全部驗證走鍵盤/滑鼠模擬路徑)。
