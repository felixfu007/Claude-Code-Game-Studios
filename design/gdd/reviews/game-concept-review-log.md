# 審查日誌:design/gdd/game-concept.md

*本檔案建立於第三輪審查(2026-07-29),補記第一、二輪的既有記錄(來源:文件本文批註與「下一步」清單),第三輪起正式使用此日誌追蹤審查歷史。*

---

## Review — 2026-07-28 — Verdict: NEEDS REVISION
Scope signal: (未於當輪記錄)
Specialists: Lean 模式(未執行 Phase 3b 專家委派)
Blocking items: (未於當輪記錄) | Recommended: (未於當輪記錄)
Summary: 第一輪審查,已依審查結果修訂本文件。詳細裁決內容未獨立記錄,修訂已併入文件本文。
Prior verdict resolved: 首次審查

---

## Review — 2026-07-29 — Verdict: NEEDS REVISION
Scope signal: (未於當輪記錄)
Specialists: 六位專家 + creative-director 綜合裁決(具體專家名單未獨立記錄)
Blocking items: (未於當輪記錄) | Recommended: (未於當輪記錄)
Summary: 第二輪審查。補上空間餘裕量化框架、好感度取捨結構要求(取捨結構須讓「滿足某對好感度」必然犧牲「另一對」)、卡牌保底機制、MVP 驗收協議重寫為可量測版本、反支柱明確排除戀愛/羅曼史路線。
Prior verdict resolved: 是——已依第一輪裁決修訂

---

## Review — 2026-07-29 — Verdict: NEEDS REVISION
Scope signal: XL(跨系統交織,5 個核心機制互相依賴,預期需要多份新 ADR:存檔架構、活棋盤場景架構、即時運算快取策略)
Specialists: game-designer、systems-designer、qa-lead、narrative-director、ux-designer、level-designer、godot-specialist、creative-director(資深綜合裁決)
Blocking items: 7 | Recommended: 11
Summary: 第三輪審查,七位專家對抗性審查後由 creative-director 綜合裁決三項架構層 P0:(1)好感度取捨結構不得用空間站位互斥實現,與空間餘裕原則同變數衝突,改用非空間軸線(行動資源競爭/聯動半徑同回合單選/卡牌打出權互斥);(2)戰鬥端/敘事端好感度美學錯位,不採雙軸分流,改為單一數值池、雙重讀取;(3)好感度對話卡牌抽取時機隨機違反支柱一/三與核心幻想,改為發牌節奏固定、牌面隨機,移除保底機制。另有 4 項阻斷性問題(陣亡連鎖列為 MVP 前置條件、MVP 驗收標準可測性修正、垂直切片地形演變測試次數由一次提升至三次、疊加規則追加同時生效對數上限)與 11 項建議修訂(以弱勝強機制錨點、風花雪月期望管理、UX漸進揭露方案重新設計、局部空間指標、Godot 4.7技術風險細化等)均已寫入文件。
Prior verdict resolved: 是——已依第二輪裁決修訂,並在本輪發現第二輪裁決本身(好感度取捨結構的「站位互斥」舉例)與空間餘裕原則存在結構性衝突,予以修正

---

## Review — 2026-07-29 — Verdict: NEEDS REVISION(輕度)
Scope signal: XL(整體系統仍屬跨系統交織,但本輪需要的修訂本身為 S 級——文字層級約束/定義補寫,不涉及重新設計或推翻既有裁決)
Specialists: game-designer、systems-designer、qa-lead、narrative-director、ux-designer、level-designer、godot-specialist、creative-director(資深綜合裁決)
Blocking items: 6 | Recommended: 2 項升級為現在處理 + 多項維持開放
Summary: 第四輪審查,七位專家對抗性審查後未發現架構層 P0 衝突(第三輪的三項架構裁決成立,不需重做)。六項阻斷全部裁定並寫入文件:(1)支柱四雙向代價硬性約束——任何好感度狀態組合與陣亡處理方案都不得產生無代價純正向結果,陣亡處理新增可驗收的存活/陣亡比較條件;(2)單一數值池須保留 delta log 而非純量,機制4「唯一牽動劇情分支來源」措辭矛盾,裁定改為軌跡讀取全部變動(依使用者選擇,移除「唯一」用詞);(3)v4 原型量測工具三項缺口補齊——陣型重複率定義為鄰接圖同構比例(僅取方向性訊號,統計門檻延後至垂直切片)、預判標記依使用者選擇裁定保留為正式「預判模式」功能、MVP 驗收協議 1/2 衝突裁定協議2為判定主軸;(4)Godot 棋盤游標高亮裁定改為單一游標狀態源,即時預覽重算範圍界定為僅移動單位相關配對。另有 2 項建議修訂由 creative-director 升級為現在處理(不留待日後):「以弱勝強」歸屬指派給未來戰鬥公式 GDD 並排除 v3 作為驗證證據;風花雪月對標的期望管理缺口寫入目標玩家輪廓表格差異化提醒。其餘建議項(地形演變相關 4 項、跨棋子比較能力細節、疊加上限 tie-break、武器射程比例、Godot 場景架構因素等)維持為可帶著走的開放項,留待 `/map-systems`、`/art-bible`、`/create-architecture` 階段處理。
Prior verdict resolved: 是——已依第三輪裁決修訂,本輪為獨立第四輪對抗性審查,未發現需推翻第三輪裁決的新架構衝突

---

## Review — 2026-07-29 — Verdict: NEEDS REVISION(輕度)
Scope signal: 本輪修訂範圍 S(全部文字層級修訂:定義補寫、約束追加、事實錯誤更正);文件整體系統規模維持 XL(承接第三輪判定)
Specialists: game-designer、systems-designer、qa-lead、narrative-director、ux-designer、level-designer、godot-specialist、creative-director(資深綜合裁決)
Blocking items: 13(六個叢集) | Recommended: 5 項建議現在寫入 + 數項維持開放
Summary: 第五輪審查,七位專家對抗性審查後未發現需推翻第三、四輪架構裁決的 P0 衝突——本輪性質與第四輪相同,是「尺規本身還有瑕疵,而 v4 即將用這把尺去量」的收斂,非架構問題。13 個阻斷項全數寫入文件:(1)MVP第5項驗收指標自相矛盾(三位專家獨立確認,信心度最高的發現)、(2)陣型重複率關係定義錯誤(同構改具名相等)並處理陣亡回合混淆、(3)發牌節奏N與戰鬥長度邊界檢查、(4)探針關卡軟性標準循環定義修正、(5)同時生效對數上限tie-break硬性約束(不得與極性相關、須玩家可預判)、(6)「聯動總分」定義與疊加規則定案順序、(7)空間餘裕框架追加視線通透度第四項指標+v4須測遮蔽地形、(8)MVP五關卡追加空間指標實測記錄要求、(9)以弱勝強MVP門檻回溯驗證義務、(10)v4敘事驗證失敗退路(保留對話影響但砍章節分支)、(11)line255 Control offset transform歸因錯誤修正、(12)密度指標命名與不等號方向矛盾修正、(13)羅曼史養成迴圈風險(narrative-director發現round4兩項裁決交互放大戀愛支線疑慮,creative-director同意風險成立但修在敘事讀取層而非戰鬥寫入層——delta log追加來源欄位、敘事解鎖判定須讀形狀特徵而非累積純量)。另有5項建議修訂由creative-director標記「建議現在寫入」並已納入:多選釘選與單選預覽衝突解法(改顯示淨聯動聚合值)、雙焦點高亮權威規則通用化、Godot Resource參照共享風險記錄、地形壓縮測試位置與判定基準、負遠狀態與空間餘裕原則張力(須有非空間維持成本)。降級/推翻項:卡牌系統幻想失諧(降級,牌庫透明可解)、MDA優先度vs投入分布(creative-director不同意此推論方向——未決項分布反映風險而非優先度倒置,但採納殘留價值即v4失敗退路)、Discovery美學缺長尾來源(降級,答案已在支柱五地形演變)、支柱四對正近未稽核(部分推翻,正近通過測試,但發現負遠的真正張力)。creative-director放行條件:本輪修訂完成後v4原型批次可正式啟動,不需要第六輪對抗性審查;若要再審,應審在v4結果回來之後(審資料是否推翻既有裁決),而非再審同一份文字。
Prior verdict resolved: 是——已依第四輪裁決修訂,本輪為獨立第五輪對抗性審查,未發現需推翻第三、四輪裁決的新架構衝突
