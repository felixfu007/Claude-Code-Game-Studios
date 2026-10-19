---
name: project-art-tone-direction-2026-10-19
description: design/art/art-tone-direction.md created 2026-10-19 to fill the "no tone doc ever existed" gap found 2026-10-16; records the key resolved/open points so the next session doesn't re-derive them
metadata:
  type: project
---

**背景**:2026-10-16 管理者發現整條美術線從未引用過遊戲類型(克蘇魯,對標《暗黑地牢》)——
`art-direction.md` 自述權威範圍只有硬參數(畫布/色盤/描邊/字型),調性從來沒有文件寫過
(`docs/reviews/art-line-never-referenced-genre-2026-10-16.md`)。2026-10-19 依派工補上
**`design/art/art-tone-direction.md`**(新檔,227 行)。

**已解決、不必重查的點**:
- **氣氛(克蘇魯陰鬱)對立繪與棋子【同樣】適用**——這是
  `docs/ai-art-service-handoff/20c-cr-002-supplement-style-criteria-2026-10-16.md`
  第二節表的明文結論(已推送承接方),不是待確認的推論。只有「繪製質感 A(半寫實)」與
  「扁平」兩個維度在兩種素材之間不同,「氣氛」維度不拆。
- **立繪 master 尺寸建議:維持 AI 原生輸出 1024×1024,不做破壞性降採樣**,顯示時用
  Linear 濾波(不是世界層的 Nearest)。推導:舊 128/480=26.7% 寬度比例套用新基準
  (介面層基準畫布 = 當下螢幕實際解析度),算到 4K 剛好落在 ~1025px,與 1024×1024 對齊。
  **這是算術推導 + 建議,不是實測、也未經 ux-designer 版面驗證**——沒有任何對話畫面
  production 程式碼可呼叫驗證(不像 `HudLayout.compute_scale()` 有函式可查)。

**尚未解決、下一個人接手前必讀**:
1. **立繪是否需要去背,現行文件自相矛盾**:`character-generation-prompts-2026-10-12.md`
   1.4 節寫「立繪不要求去背」,但派工單轉述家用端問題是「要不要補測 128² 以上的 AI
   **去背**品質」。本檔沒有判定哪邊對,原樣登記交回。
2. **`character-generation-prompts-2026-10-12.md` 1.2 節的光源描述
   (`soft even studio lighting from upper-left`)與新調性(低調光/硬光源)衝突,需要取代**
   ——新詞彙草稿已在 `art-tone-direction.md` 第三節,但舊檔本身尚未改(既有檔案需先問,
   不是我能動的)。
3. **戊(麥子健)的 `confident calculating smirk` 表情**與五位角色的色相家族分配
   (甲冷藍/丁冷近黑/乙米灰/丙壓暗棕/戊暖棕紅)都是在「動漫調性」下做的創作提案,
   轉向陰鬱降飽和之後是否仍然成立,**未覆核**。
4. **今天之前已產出的 19 張候選圖(第三輪 16 張 + 2026-10-16 當天 3 張)調性可能已經不對**
   ——下一個人動用這批圖之前先確認要不要重產,見
   `docs/reviews/art-line-never-referenced-genre-2026-10-16.md` 第五節。
5. **底模仍未選定**——已知兩個候選(Animagine 偏扁平但動漫、SDXL base 偏寫實但不扁平)
   各只滿足一半,需要找第三個,與 [[project_base_model_candidates_2026-10-13]] 是同一條
   未結的線,本次沒有新進展。

**How to apply**:下次處理 prompt 改寫、底模選定、或對話畫面立繪版面設計時,先讀
`design/art/art-tone-direction.md` 全文(227 行,不長),不要重新推導調性判準——
但上面 5 項開放問題仍要向管理者或對應專家確認,不能假設已經定案。
