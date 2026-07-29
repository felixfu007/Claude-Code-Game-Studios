<!-- STATUS -->
Epic:
Feature: 好感度—位置連鎖 v4 原型(新手驗證批次)
Task: Track A(戰鬥端)+ Track B(敘事端)皆已建好,待真人測試與 Phase 6-7 debrief/報告
<!-- /STATUS -->

# 目前工作狀態

**概念**:好感度—位置連鎖(《弈緣》核心機制)— v1-v3 已 PROCEED,design-review 第三/四/五輪裁決要求 v4 作為進入 `/design-system` 前的硬性門檻

**design-review 進度**:第五輪(2026-07-29)判決 NEEDS REVISION(輕度),18 項發現(13 阻斷 + 5 建議)已全數修訂寫入 `design/gdd/game-concept.md`。creative-director 放行:不需要第六輪審查,直接進入 v4 原型。

## v4 原型 — 兩軌並行

design-review 認定 v4 實際上是兩個完全不同的驗證(戰鬥端已有方向性驗證但缺外部效度;敘事端從未驗證過):

### Track A — 戰鬥/位置連鎖(進行中)

- **路徑**:HTML,延續 `prototypes/affinity-position-concept-v3/` 程式碼
- **檔案**:`prototypes/affinity-position-concept-v4/prototype.html` + `README.md` — **已建好**
- **新增機制**:預判標記 UI、固定節奏發牌(N=2,牌面隨機/玩家決定是否打出)、非空間取捨機制(同一單位同時多對正好感時只有最近一對生效)、遮蔽地形關卡(視線通透度測試)、陣型重複率自動追蹤(依觸發/未觸發卡牌分組)、跨戰鬥 session 統計面板
- **下一步**:需要 3-5 位真正新手實際測試(教學後 2-3 場戰鬥 + 決定性探針關卡對照 + 遮蔽地形關卡),完成後回到 `/prototype` 流程 Phase 6(debrief 五問)→ Phase 7(REPORT.md)→ Phase 8(creative-director 審查,lean 模式下跳過)

### Track B — 敘事軌跡系統(已建好,待真人測試)

- **路徑**:Paper(故事地圖 + 模擬遊玩紀錄)
- **檔案**:`prototypes/affinity-position-concept-v4/track-b-narrative/story-map.md` + `play-log.md` + `README.md` — **已建好**
- **角色設計**:三人結構(甲/乙/丙,佔位代號)——甲同時對乙、丙有好感度潛力,3 次支援對話名額 + 4-5 張戰鬥卡牌必須在兩段關係間分配,製造敘事層的取捨
- **驗證的核心問題**:round 5 design-review 的「羅曼史養成迴圈」設計測試——一名全程只對單一角色打好感度卡牌的玩家,其敘事解鎖結果應與均衡經營的玩家不同,但不應單純更多或更好;資源預算是否真的能阻止兩段關係同時達到最深交情
- **自我模擬已發現的缺口**:`play-log.md` Session 3 發現軌跡形狀分類規則有中間地帶缺口(只定義了 5 種乾淨形狀,真實投入模式常落在查不到表的中間地帶)——`/design-system` 階段需要處理
- **下一步**:找真人讀者實際「扮演」一輪,用 `play-log.md` 最後的五個引導問題 debrief

**相關檔案**:
- `design/gdd/game-concept.md` — 遊戲概念文件(第五輪修訂完成)
- `design/gdd/reviews/game-concept-review-log.md` — 五輪審查完整記錄
- `prototypes/index.md` — 原型索引(v4 完成後需更新)
- `prototypes/affinity-position-concept-v3/` — v3 HTML 原型(PROCEED,v4 的程式碼基礎)
- `prototypes/affinity-position-concept-v4/` — v4 Track A(本次新建)
