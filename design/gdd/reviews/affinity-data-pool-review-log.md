# Review Log: 好感度數值池(Delta Log)

> 本檔記錄 `/design-review` 指令對 `design/gdd/affinity-data-pool.md` 的正式審查歷程。文件本身在此之前已累積 6 輪內部修訂(見 GDD 檔頭修訂記錄),但本檔案是第一次以 `/design-review` 指令正式登記的審查結果。

## Review — 2026-08-03 — Verdict: APPROVED(修訂後)
Scope signal: L(4+ formulas, cross-system integration, storage architecture likely needs a new ADR)
Specialists: game-designer, systems-designer, qa-lead, narrative-director, godot-specialist, performance-analyst(並行審查)、creative-director(綜合裁決)
Blocking items: 8(修訂前)→ 0(修訂後) | Recommended: 6(全數採納)
Summary: 第七輪正式化 `/design-review`。六位專家在文件已歷經 6 輪內部修訂的高成熟度基礎上,仍各自發現新問題,主要集中於:(1)資料層契約缺陷——`Q` 定義域未設正整數約束、`low_confidence` 於 `n(p)=0` 未定義、AC-55/AC-12 的可驗證性缺口;(2)`source_absence`(3g)語意越權——把「零記錄」的事實斷言寫成「玩家主動選擇」的意圖斷言,在深度門檻閘控來源開放的情境下會誤讀結構性鎖死為玩家能動性;(3)`low_confidence` 旗標與 Track B 順序軸需求的結構性錯位(AC-49 正典範例自身觸發低信心);(4)陣亡角色讀值查詢的歷史 `t_query` 僅有能力、未有義務;(5)累積 8+ 條硬性交接義務缺乏跨文件追蹤機制。全部 8 項阻擋皆已於本輪修訂解決,修法均為資料層/流程層的局部修補,未推翻任何既有架構裁決。`systems-index.md` 同步新增支援對話系統風險列與跨系統義務登記表。creative-director 建議修訂完成後不再進行第八輪全面審查(邊際報酬遞減,剩餘風險需靠 playtest/原型/下游 GDD 推進)。
Prior verdict resolved: 是(本檔案第一次正式登記,GDD 檔頭記錄的第 1-6 輪內部修訂已在本輪審查中確認全數妥善收斂,無需重複列出)

## Review — 2026-08-10 — Verdict: NEEDS REVISION(修訂後,同一 session 內完成)— 第九輪
Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, narrative-director, godot-specialist, performance-analyst(並行審查)、creative-director(綜合裁決)
Blocking items: 4(修訂前)→ 0(修訂後) | Recommended: 3(全數採納)
Summary: **本檔案的補登紀錄(2026-08-10 第十一輪回溯補登,回應對抗性覆核 qa-lead 發現本檔案自第七輪後未再更新,與 GDD 標頭記錄的三輪後續審查脫節)**。第九輪審查對象是同日稍早「第八輪 creative-director 裁決」(非正式 `/design-review` 流程,裁決範圍涵蓋深度軸定性 C-2、陣亡配對讀取規則 F3-1、begin/end 權杖重入三項議題)落地修訂後的文件本身,是這次落地修訂首次接受正式審查。六位專家獨立收斂發現 4 項推導缺口:`t_death(p)` 完全無資料通道(僅有凍結規則,未定義死亡狀態如何進入本系統)、深度資格閘門檻(`pure_combat_floor`)未定義且與 `game-concept.md` 既有範例互斥、Formulas 共用符號表與公式一二簽章未同步 Core Rules #3 新增的陣亡條件式預設、Track B 交付項第 3 條(配對層級二值資格閘是否違反「不隱含排序」)範圍未裁決。使用者核准 4 項決策(新增陣亡標記表/陣亡通知介面、結局資格閘改用 `n(p)≥n_gate_min`、Track B 第 3 條採條件式違規裁決、begin/end 現在就在 GDD 層定義權杖逾時獨立錯誤分類)後,同一 session 內完成修訂。詳見 GDD 標頭第九輪修訂記錄。
Prior verdict resolved: 是(第八輪 creative-director 裁決本身首次經正式審查)

## Review — 2026-08-10 — Verdict: NEEDS REVISION(修訂後,同一 session 內完成)— 第十輪
Scope signal: M(目標型覆核,僅涵蓋第九輪新增的兩項介面,非全量重審)
Specialists: systems-designer、qa-lead(並行審查)、creative-director(綜合裁決)
Blocking items: 4(修訂前)→ 0(修訂後) | Recommended: 1(已採納)
Summary: **本檔案的補登紀錄(2026-08-10 第十一輪回溯補登)**。第十輪為目標型 `/design-review`,依第九輪 creative-director 建議縮小審查範圍,僅覆核陣亡標記表與 `n_gate_min` 兩項新介面。發現:陣亡標記表值域誤植為「≥1」(應為「≥0」,死亡通知記錄的是未遞增的計數器現值);AC-25/AC-75 未強制陣亡後全域計數器推進,無法區分「正確凍結」與「完全未凍結、直接沿用 `t_now`」兩種實作;`n_gate_min` 宣稱的 `n(p)` 預設語意與 Core Rules #3 對陣亡配對的凍結預設字面矛盾;陣亡標記表跨結構不變量第 5 條(新增於第九輪)零測試涵蓋。四項阻擋皆已於同一 session 內修訂完成,另採納 `n_gate_min` 正整數定義域約束的建議修訂,並補上 AC-63 的 B(配對另一成員)存活狀態不影響行為的明文提醒(**2026-08-10 第十二輪補登,回應對抗性覆核 qa-lead 發現本欄位原漏列此項,僅在 GDD 標頭第十輪修訂記錄出現**)。詳見 GDD 標頭第十輪修訂記錄。
Prior verdict resolved: 是(第九輪 4 項阻擋修訂本身首次經審查)

## Review — 2026-08-10 — Verdict: NEEDS REVISION → 已修訂(同一 session 內完成)— 第十一輪
Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, narrative-director, godot-specialist, performance-analyst(並行審查)、creative-director(綜合裁決,verified 逐條驗證高風險宣稱)
Blocking items: 6(修訂前)→ 0(修訂後) | Recommended: 11(1 項採納為校準義務,1 項判定不需修改,其餘 9 項採納)
Summary: 完整模式 `/design-review`,目的是驗證第九、十輪修訂本身是否成立(依本文件歷史慣例,重大修訂後應再跑一次驗證)。creative-director 綜合裁決確認全部 6 項阻擋皆源自第九、十輪新增的兩個介面(陣亡標記表、`n_gate_min`)自身的編輯疏漏,**無架構層級問題**:(1)AC-25/AC-75 第十輪的補強在合法邊界值 `λ=1` 下代數恆等,無法區分正確/錯誤實作,已補上 `λ<1` 與非零凍結基準前提;(2)同結算步內陣亡通知與寫入呼叫順序會改變寫入合法性,與「不需要額外排序規則」的宣稱矛盾,已限定範圍並登記給戰棋移動與交戰系統的順序義務;(3)公式四(預判讀取)對陣亡配對的行為未定義且會算出與既有凍結不變量矛盾的結果,裁定一律拒絕呼叫,新增 AC-79;(4)`M`/`n_min_segment` 補齊比照 `Q`/`n_gate_min` 的正整數定義域,陣亡標記表鍵值型別與生命週期權杖補上比照 `Pair` 的值型別/非重用提醒,AC-55 診斷範圍排除說明明文化;(5)本審查記錄檔案三輪未同步(即本次補登);(6)Dependencies「義務 A」用詞自我矛盾已釐清,新增沉默處置驗證義務,連動修訂 `game-concept.md` 常設風險重測條件與 `systems-index.md` 登記列。creative-director 並查證推翻了兩項專家批評——`n_gate_min` 是否重啟刷好感漏洞(查證後不成立,`game-concept.md` 同日已核准),qa-lead 對 AC-64 第三種非法情形的「重複覆蓋」質疑(查證後判定為合理的獨立邊界值測試,非贅述)。**建議下一輪(若需要)改為 systems-designer + qa-lead 目標型複核,不再對本文件跑六人全面審查**——這是本文件連續第三輪(第九、十、十一)發現全部集中在同一個範圍(陣亡標記表 + `n_gate_min` 兩項介面)的訊號,建議未來以一次集中重寫取代逐點修補。
Prior verdict resolved: 是(第九、十輪落地修訂本身首次經完整審查)

## Review — 2026-08-10 — Verdict: NEEDS REVISION → 已修訂(同一 session 內完成)— 第十二輪(目標型)
Scope signal: S(目標型覆核,僅涵蓋第十一輪的 6 項修訂本身)
Specialists: systems-designer、qa-lead(並行審查,依第十一輪 creative-director 建議縮小範圍,未動用其餘四位專家)
Blocking items: 0 | Recommended: 6(全數採納)
Summary: 依上輪建議,本輪僅由 systems-designer + qa-lead 覆核第十一輪 6 項修訂是否成立,不重跑六人全套。結論:第十一輪的修法**全數站得住腳,沒有一項被推翻**。但發現 6 項更小範圍的殘留問題:(1)AC-25/AC-75 的 `λ<1` + 非零基準前提只排除代數恆等的情形,未排除「差距小於 ±0.01 容許誤差」的浮點層級收斂(systems-designer 獨立重新推導發現),已補上可觀測差距前提;(2)AC-44 的「存活配對」限定沒有傳播到同樣呼叫公式四的姊妹條目 AC-43/AC-46/AC-50,已同步補上;(3)Dependencies 對好感度—位置連鎖系統的記憶化快取列、Open Question 9 皆未告知呼叫方公式四對陣亡配對的新限制,已補充提醒;(4)`game-concept.md` 第 86 行把自己在本輪(第十一輪)新增的句子誤標為「第九輪」,三個獨立來源(GDD 標頭、`systems-index.md`、review-log)皆證實應為第十一輪,已修正——這是典型的「同一句話複製貼上時輪次標籤沒跟著改」疏漏,已當場攔截,未讓其累積成下一輪才發現的接縫;(5)AC-12 有一處過時行號引用(「line 295」),已改為章節名稱引用避免未來再度偏移;(6)本檔案第十輪條目漏列 AC-63 附註,已補上。**沒有發現任何一項第十一輪修法被推翻,也沒有發現新的設計理論或架構層級問題**——本輪性質純屬精確度/傳播性收尾。
Prior verdict resolved: 是(第十一輪落地修訂本身首次經審查)

## Status Update — 2026-08-10 — APPROVED
使用者於第十二輪驗證完成後核准將本文件標記為 Approved——連續兩輪(第十一、十二輪)未再發現任何架構層級或設計理論缺陷,符合第十一輪 creative-director 訂下的停止條件。`systems-index.md` Systems Enumeration 第 1 列與 `affinity-data-pool.md` 標頭 Status 已同步更新。剩餘已知遺留項(D-1、F2-1、F2-2 等)為既有的、非本文件範圍內的跨文件缺口,不影響本次核准。
