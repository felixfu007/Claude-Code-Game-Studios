# 旋鈕資料檔 ↔ 設計文件 對照表(2026-11-11)

> 資料檔:`assets/data/tuning/tuning_knobs.txt`(23 鍵,2026-11-04 起)。規劃書:`docs/reviews/tuning-knobs-data-driven-plan-2026-11-04.md`。
> 目的:明天要調難度的人,能從每個數字找到它的設計出處與理由。
> **只列出差異,不判斷誰對。出處一律用節名,不用行號。**
> 單位數值(HP/ATK/DEF/移動力等)不在旋鈕檔,在 `assets/data/units/*_roster.txt`,本表不逐一列。
> 驗證方式:本次逐一讀設計文件原文比對(人工閱讀,非引擎執行);「文件寫的值」皆取自下列出處節的原文。
> 縮寫:APC = `design/gdd/affinity-position-chain.md`;SCS = `design/gdd/skill-card-system.md`;USP = `design/quick-specs/unit-stats-provisional.md`。

## 結論

- 23 鍵:**相同 23 / 不同 0 / 文件找不到 0**。
- 但有 4 項「值相同、文件說法過期或有落差」,見「值一致但文件側有落差」一節 —— 調難度前請先讀,否則會被舊文字誤導。

## 對照表

| 資料檔鍵 | 資料檔現值 | 設計文件出處(檔 + 節名) | 文件寫的值 | 一致? | 理由/公式出處 | 備註 |
|---|---|---|---|---|---|---|
| `deck,opening_hand_size` | 5 | SCS「Tuning Knobs」表『開局手牌』 | 5(安全範圍 [3, 7]) | 相同 | SCS「Tuning Knobs」:與手牌上限綁在一起,滿手開局是刻意的,第一回合就要做取捨;抽牌數推算見 SCS「公式四:單場戰鬥的抽牌數」(5 + T = 9~11 張) | 改它會動公式四的卡池規模下限(> 11 張) |
| `deck,hand_size_limit` | 5 | SCS「Tuning Knobs」表『手牌上限』;SCS「Detailed Rules」二、發牌與手牌 | 5(安全範圍 [3, 7]) | 相同 | 防囤牌規避好感度時近性衰減(`affinity-data-pool.md` Dependencies 對技能卡牌系統的硬性交接義務;SCS「Dependencies」六項繼承義務第 2 項) | 上調會放大囤積讀值,單場內放大倍數約等於上限張數 |
| `deck,cards_drawn_per_turn` | 1 | SCS「Tuning Knobs」表『每回合補牌』 | 1(安全範圍 [1, 2]) | 相同 | 管理者裁決:稀缺是時間上的 | 🔴 SCS 註明改成 2 = 推翻設計承諾,要回頭改 Player Fantasy,不是純數值調整 |
| `card_modifier,atk_delta_min` | -4 | USP「7-4. 給 skill-card-system.md 甲類的尺度錨點」;SCS「公式一:甲類的有效戰鬥數值」(要求設累計夾限) | `ΣΔatk` [−4, +6] | 相同 | USP 7-4:錨在 `Φ` 上不錨在基準值上;須與 `Φ` 的 −4/+12 校準 | SCS「Tuning Knobs」表仍寫「待基準表」(過期,見落差 A) |
| `card_modifier,atk_delta_max` | 6 | 同上 | `ΣΔatk` [−4, +6] | 相同 | USP 7-4:上界約等於兩張 +3 疊加的實務上限,且低於 `Φ_max = +12`,保證佈局理論上限高於純卡牌 | 單卡 \|Δ\| 建議 1~3(不在旋鈕檔,逐卡定義在卡表) |
| `card_modifier,def_delta_min` | -3 | USP「7-4」 | `ΣΔdef` [−3, +4] | 相同 | USP 7-4:刻意低於 ATK 側 | 見落差 A |
| `card_modifier,def_delta_max` | 4 | USP「7-4」 | `ΣΔdef` [−3, +4] | 相同 | 原理由是「DEF 基準只有 3~4,同樣絕對加成相對漲幅大」;USP 自註現行 DEF 4~8 故 +4 偏保守,放寬有依據 | 調 DEF 卡太弱時,這是文件明文認可的放寬點 |
| `combat,guard_min` | -2 | APC「Formulas」公式四;APC「Tuning Knobs」『【2026-10-30 新增】減傷與獨行減傷的旋鈕』表 | `GUARD_MIN = −2`(安全範圍 −3 ~ 0) | 相同 | 公式四:`guard_total = clamp(guard(Φ_def) + lone_guard, GUARD_MIN, GUARD_MAX)` | 設 0 = 關閉負 Φ 與戊相鄰的代價通道,須 creative-director 裁決 |
| `combat,guard_max` | 3 | 同上 | `GUARD_MAX = +3`(安全範圍 2 ~ 5) | 相同 | 避免 Φ 達 +12 時傷害歸零;<2 會截斷合作 Φ=+3 的減傷 2 | 單元測試目前釘死 3 / -2(規劃書第 2 節) |
| `combat,lone_far_distance` | 3 | APC「Tuning Knobs」2026-11-03 加註(amend2)表『「獨行距離閾值」列』;APC「Formulas」公式五 | 3(語意改為「超過 2 格即失效」) | 相同 | amend2 第 1 節(`docs/reviews/affinity-core-redesign-spec-amend2-2026-10-30.md`) | 閾值語意已變,不再是 +2 的觸發線 |
| `combat,lone_far_guard` | 0 | APC「Tuning Knobs」amend2 表『`LONE_FAR_GUARD`』;公式五 | 0(原 +2;範圍 0~1) | 相同 | 落單(d_min ≥ 3 或無隊友)不再給減傷;>0 = 重新獎勵孤立 | 舊值 +2 仍留在公式五歷史文字與 2026-10-30 條文中 |
| `combat,lone_near_distance` | 1 | APC「Formulas」公式五(d_min = 1 → −1) | 1 | 相同 | 公式五:貼身 d=1 付代價 | Tuning Knobs 表只列懲罰值 −1,未把距離 1 列成獨立旋鈕;值來自公式五條件式 |
| `combat,lone_near_guard` | -1 | APC「Tuning Knobs」表『相鄰懲罰(戊 d_min=1)』;公式五 | −1(範圍 −2 ~ 0) | 相同 | 不隨出手條件化;設 0 = 戊貼隊友無代價 | 與 `GUARD_MIN` 的夾限互動見 APC 公式四 |
| `combat,lone_mid_guard` | 2 | APC「Tuning Knobs」amend2 表『`LONE_MID_DISTANCE` / `LONE_MID_GUARD`』;公式五 | +2(範圍 1~3) | 相同 | 騎牆減傷:離隊友剛好 2 格才有;太高則戊守 2 格近乎不死 | 對應的距離常數 `LONE_MID_DISTANCE`(2)**不在資料檔**(死常數,見落差 C) |
| `combat,hold_back_distance` | 2 | APC「Tuning Knobs」amend2 表『`HOLD_BACK_DISTANCE`』;公式五『留一手』 | 2(範圍 2~3;與 `LONE_MID_DISTANCE` 同值) | 相同 | 兩者分叉則騎牆的減傷與代價不在同一格,須重新裁決 | 資料檔沒有任何機制強制它與 `LONE_MID_DISTANCE` 同值(後者不在檔內),見落差 C |
| `combat,hold_back_penalty` | 1 | APC「Tuning Knobs」amend2 表『`HOLD_BACK_PENALTY`』;公式五『留一手』 | 1(範圍 1~2) | 相同 | >2 時戊從 d=2 出手不值得,騎牆退化為「全程貼身或脫隊」 | 協議 2 attempt-4 未通過、attempt-5 壓線通過(APC 公式五 2026-11-03 推估段) |
| `affinity,delta_positive_adjacent` | 3 | APC「Detailed Rules」R3 距離—數值曲線表;APC「Tuning Knobs」第一張表『正向·緊鄰』 | +3(範圍 2~5) | 相同 | R3 既有行為;太高則合作輾壓、無人走對立 | 🔴 與其餘四項曲線值與 `enemy_advantage_pct`(0.20)**不得各自獨立調整**(APC 跨系統校準義務) |
| `affinity,delta_positive_far` | -1 | 同上,『正向·疏遠』 | −1(範圍 −3 ~ 0) | 相同 | 太重會讓「暫時分開」代價過高 | 同上校準義務 |
| `affinity,delta_negative_adjacent` | -1 | 同上,『負向·緊鄰』 | −1(範圍 −3 ~ 0) | 相同 | 同上 | 同上 |
| `affinity,delta_negative_far` | 2 | 同上,『負向·疏遠』 | +2(範圍 1 ~ 正向值) | 相同 | ⚠️ 不得 ≥ 正向緊鄰值,否則 R6 路線不對等反轉 | 同上 |
| `affinity,delta_neutral` | 0 | APC「Detailed Rules」R3 表(距離 2 一列) | 0 | 相同 | 距離 2 為刻意死區,靠近與遠離都必須是明確選擇 | Tuning Knobs 表『死區距離 = 2』標「固定」;死區的**距離**(`DISTANCE_ADJACENT`/`DISTANCE_FAR`)留在程式碼(2026-11-04 管理者裁決) |
| `affinity,phi_min` | -4 | APC「Formulas」公式三;APC「Tuning Knobs」第一張表『`Φ` 夾限』 | Φ_min = −4 | 相同 | 取相鄰四格飽和點 4×(−1);`design/registry/entities.yaml` 亦登記;2026-08-31 管理者裁決 | 🔴 承重:調它 = 直接調戰力下限。夾限只夾一次,在 `bonus_breakdown_for_at` 的加總總和上(`docs/registry/architecture.yaml` forbidden pattern `phi_clamp_treated_as_a_safety_net`) |
| `affinity,phi_max` | 12 | 同上 | Φ_max = +12 | 相同 | 取相鄰四格飽和點 4×(+3);線數不設限(2026-08-31 裁決)後夾限是唯一邊界,6 條正向距 1 線理論和 +18 → 壓回 +12(AC-R7) | 🔴 承重。假設 `amp = 1`;卡牌系統定案 `amp` 恆為 1(SCS「Dependencies」繼承義務第 4 項),故不需重算 |

## 值一致但文件側有落差(調難度前請先讀)

- **落差 A:卡牌累計夾限,SCS 的 Tuning Knobs 表仍寫「待基準表」。** 實際值已在 USP「7-4」定案並實作為 [−4, +6] / [−3, +4]。SCS 的 Open Questions OQ-1 已指向 USP 7-4,但 Tuning Knobs 表那兩列(`ΣΔatk` / `ΣΔdef` 累計夾限)沒更新。要找這四個數字的出處,看 USP 7-4,不要看 SCS Tuning Knobs。
- **落差 B:APC「Tuning Knobs」仍寫「是否改外部資料檔,交 gameplay-programmer 與 lead-programmer 決定」。** 實際已於 2026-11-04 起搬到 `assets/data/tuning/tuning_knobs.txt`(`grep -rln "tuning_knobs" design/` 零命中)。APC 還寫「存放:沿用 `LONE_*` 既有做法放 `CombatRules` 常數」,此句現已不成立。
- **落差 C:`LONE_MID_DISTANCE`(2)出現在 APC 的旋鈕表與公式五,但不在資料檔。** 規劃書第 1.3 節記載它是死常數:`lone_guard()` 以 fallthrough 得到中段,從不讀它,改它沒有效果。後果:文件說「`HOLD_BACK_DISTANCE` 與 `LONE_MID_DISTANCE` 須同值」,但資料檔裡只有 `hold_back_distance` 可調,調它會讓騎牆減傷(固定在 d=2)與留一手代價(在新距離)分叉,而**沒有任何旋鈕能把兩者拉回同一格**。調 `hold_back_distance` 前請先確認這個行為是你要的。(此項規劃書列為待裁決,本表不判斷。)
- **落差 D:`DISTANCE_ADJACENT`(1)/`DISTANCE_FAR`(3)留在程式碼,不在資料檔。** APC 旋鈕表稱死區距離「固定」、`lone_*` 的距離閾值有範圍 2~4。`lone_far_distance` / `lone_near_distance` 在資料檔內,但曲線的相鄰/疏遠距離不在。`docs/registry/architecture.yaml` 的飽和算術(距離 1 恰有 4 格 → 4×(+3) = Φ_max)依賴這兩個距離固定。

## 資料檔之外、設計文件列為旋鈕但本檔未涵蓋的項目(僅供對照,不屬 23 鍵)

- `enemy_advantage_pct` 階梯 {0.05, 0.20, 0.35}:`design/gdd/tactical-combat-system.md`「Formulas」公式二、USP「7-3」。在名冊側,不在旋鈕檔。
- 甲類單卡 \|Δ\| 1~3、持續回合 r ∈ {1, 2}、丙類幅度 m = ±1~±3:SCS「Tuning Knobs」,逐卡定義在卡表。
- 戰棋地形 `cost`(1/2/3):`tactical-combat-system.md`「Tuning Knobs」,規劃書第 1.3 節列為待裁決。
- 敵方回合節奏(0.3s / 0.12s 等)屬手感,規劃書建議第二階段,未搬。

## 建議在各設計文件加的指路註記(只建議,未改任何檔)

1. **`design/gdd/affinity-position-chain.md` →「Tuning Knobs」節,『【2026-10-30 新增】減傷與獨行減傷的旋鈕』小節末段(目前寫「是否改外部資料檔…」那一條)。** 建議:「`GUARD_*`、`LONE_*`、`HOLD_BACK_*`、`Φ` 夾限與距離曲線四項現值,已於 2026-11-04 搬至 `assets/data/tuning/tuning_knobs.txt`(`combat` / `affinity` 兩區);本節仍是各值的設計理由來源,調值時以資料檔為準、並回頭更新本節。」並刪除或加註「存放:沿用 `CombatRules` 常數」。
2. **同檔 →「Tuning Knobs」節 amend2 表『`LONE_MID_DISTANCE`』列。** 建議:「此距離常數目前不在資料檔,且程式不讀它(見 `docs/reviews/tuning-knobs-data-driven-plan-2026-11-04.md` 第 1.3 節);`hold_back_distance` 可調而它不可調,兩者同值的約束目前無機制保證。」
3. **`design/gdd/skill-card-system.md` →「Tuning Knobs」節,開局手牌 / 每回合補牌 / 手牌上限三列。** 建議:在表後加一句「這三項現值在 `assets/data/tuning/tuning_knobs.txt` 的 `deck` 區。」
4. **同檔 →「Tuning Knobs」節『`Σ Δatk` / `Σ Δdef` 的累計夾限』兩列(目前寫「待基準表」)。** 建議:改為「[−4, +6] / [−3, +4],出處 `design/quick-specs/unit-stats-provisional.md` 7-4;現值在 `tuning_knobs.txt` 的 `card_modifier` 區」。
5. **`design/quick-specs/unit-stats-provisional.md` →「7-4. 給 skill-card-system.md 甲類的尺度錨點」節末。** 建議:「這三項的現行資料檔位置:`assets/data/tuning/tuning_knobs.txt` 的 `card_modifier` 區。」
6. **`design/gdd/tactical-combat-system.md` →「Tuning Knobs」節末(『不由本系統擁有的旋鈕』小節附近)。** 建議:加一句「減傷、獨行、留一手、好感度曲線與卡牌夾限的資料檔在 `assets/data/tuning/tuning_knobs.txt`,設計理由見 `affinity-position-chain.md` 與 `skill-card-system.md` 各自的 Tuning Knobs。」(僅指標,不複述定義,符合 design-docs 規則的單一來源原則。)
7. **`design/registry/entities.yaml`。** 建議:`phi_min` / `phi_max` 相關條目的 notes 加一句資料檔位置指標(本表未逐條核對該登記表其餘條目;僅讀到 Φ 夾限兩條的存在)。

## 本表未查證之處

- 未開引擎、未跑程式驗證資料檔鍵確實被 `src/` 讀取(規劃書與 epic 各 story 為依據,本次未重驗)。
- `design/gdd/tactical-combat-system.md` 的 Tuning Knobs 節本次僅確認其標題存在,未逐列比對是否亦重述上述旋鈕(本表只用 APC、SCS、USP 三份為出處)。
- `design/registry/entities.yaml` 僅核對 Φ 夾限兩條,其餘旋鈕(guard、lone 等)是否已登記,本次未查。
