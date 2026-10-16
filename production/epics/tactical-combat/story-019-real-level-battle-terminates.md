# Story 019: 真實關卡打完一整場 —— 5 對 5、真實地形、真實 AI

> **Epic**: 戰棋移動與交戰系統(#4)—— `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready
> **Layer**: Integration
> **Type**: Integration
> **Estimate**: M
> **開單依據**: 2026-10-16 管理者裁決 —— 選項逐字為「**再證一次,這次用真關卡(推薦)**」。
> 四個選項(真關卡 / 戰鬥 HUD 預判標記 / 支援對話系統 / 上午真關卡下午寫設計)中選本案。

## Context

### 🔴 story-018 證明了什麼、沒證明什麼

`story-018`(2026-10-16 完成)證明了**勝負結算這條鏈在畫面側會動**:
真實 `BattleScreen.tscn` → 玩家操作 → `battle_ended` → 結果標籤。

**但它用的是 1 對 1 的合成夾具**(`test_fixture_roster_duel.txt`,一擊見勝負)。
亦即它證明的是**機制**,不是**內容**。當場查:

```bash
grep -v "^#" assets/data/units/test_fixture_roster_duel.txt
# 1,TESTHERO,PLAYER,999,99,0,1,1,1,0,0
# 2,TESTDUMMY,ENEMY,1,0,0,1,1,1,1,0
```

**真實關卡是 5 對 5**:
```bash
grep -v "^#" assets/data/units/vs01_roster.txt | awk -F, '{print $3}' | sort | uniq -c
#   5 ENEMY
#   5 PLAYER
```

🔴 **一場真實的 5 對 5 戰鬥,從開局打到勝負,全專案從來沒有跑過一次。**
沒有任何東西在防「永遠打不完」「回合卡死」「AI 踩步」這幾件事。

### 現成可用的三樣東西(不要重新發明)

1. **真實場景載入 + 真實入口驅動的既有範本** ——
   `tests/integration/ui/battle/battle_screen_battle_outcome_test.gd`(story-018,243 行)。
   **照抄它的 `_load_battle_screen()` 結構,但【不要】注入任何 `*_path_override`** ——
   本 story 要的就是真實 vs01 資料。
2. **AI 是陣營無關的,可以拿來驅動我方**:
   ```
   src/ai/greedy_tactical_ai.gd:30
   static func decide(state: BattleState, unit_id: int, can_move: bool, can_attack: bool) -> Dictionary
   ```
   它自己從 `unit.faction` 推出敵對陣營(`_opposing_faction()`),**傳我方單位進去就會替我方決策**。
   回傳 `{"move_to": Vector2i 或 null, "attack": 目標 id 或 -1}`。
3. **敵方回合的真實入口**:`await instance._end_faction_phase_pressed()`。

## Acceptance Criteria

- [ ] **AC-1 終止性**:載入真實 `BattleScreen.tscn`(**零 override**),雙方都由
      `GreedyTacticalAI` 驅動,一路打到 `outcome() != ONGOING`。
      斷言最終結果是 `VICTORY` **或** `DEFEAT`,**不是 `ONGOING`**。
      🔴 **本 story 不在乎誰贏。** 斷言的是「它會結束」,不是「我方會贏」。
- [ ] **AC-2 回合數上限是量出來的,不是猜的**:先實際跑一次、量出真實回合數,
      再把上限設為「實測值 + 合理餘裕」,並**在測試註解裡寫下實測值**。
      🔴 **上限被觸發時必須是明確的測試失敗**,不得靜默通過。
- [ ] **AC-3 玩家側走真實入口**:我方單位的移動/攻擊一律經
      `instance._controller.click_tile()`(先點自己、再點目標格),
      **每一步都斷言回傳的 `action`**。不得直接呼叫 `BattleState` 的 mutator。
- [ ] **AC-4 敵方側走真實畫面路徑**:`await instance._end_faction_phase_pressed()`。
- [ ] **AC-5 執行時間必須量測並揭露**:`ENEMY_STEP_PAUSE_SECONDS = 0.3` 是**真實秒數**,
      5 個敵人 × N 回合會實際花掉那麼久。**在註解裡寫下本測試實測耗時。**
      🔴 **若單一測試超過 30 秒,先停下來回報,不要自己決定要不要收**
      —— 那會是一個需要裁決的取捨(真實路徑 vs 測試套件總時長)。
- [ ] **AC-6 誠實揭露它證明不了什麼**:比照 story-018 的檔頭寫法,至少要寫出
      「用同一支貪婪 AI 驅動我方**不是人類的打法**,所以本測試不證明平衡性、不證明好不好玩,
      只證明系統在一整場戰鬥中不會卡死或崩潰」。

## Affected Files

**依 2026-10-12 管理者裁決,下列既有程式碼檔在本工作單明文範圍內,可直接改,不必先問。**

| 檔案 | 預期動作 |
|---|---|
| `tests/integration/ui/battle/battle_screen_real_level_battle_test.gd` | 🔴 **新建(第一個動作就寫這個檔)** |
| `src/ui/battle/battle_screen.gd` | **僅在必要時**新增 `diagnostic_*` 唯讀 getter。**不得改動任何既有行為。** |

🔴 **若測試顯示真實關卡打不完、或任何一方卡住 —— 那就是抓到東西了。
停下來回報,不要自己修遊戲邏輯。** 本 story 的價值在於它可能會紅。

## 🔴 五個會咬人的陷阱

1. **`set_script()` 會把先前賦值的屬性清回預設值** —— story-018 踩過(三條測試靜默測錯情境,
   不報錯)。本 story 若用到 mutant 子類別,`set_script()` 一律寫在任何屬性賦值**之前**。
2. 🔴 **GdUnit4 在實際值為【空字串】時,失敗報告的 `Expecting` 與 `but was` 兩行
   去色後逐字相同**(它用底色標缺字)。**看到「兩個相同的字串不相等」時,先懷疑實際值是空的**,
   不要去追字串編碼。story-018 已被這個誤導過一次。
3. **lambda 對 `int`/`bool` 是值捕捉**,lambda 內的賦值不會寫回外層區域變數。
   要計數就用單元素 `Array`(參考型別)。
4. **地形檔格式不支援 `#` 開頭的註解**(只有 roster CSV 支援)—— 但本 story 用真實地形檔,
   不會自己寫地形,列在這裡只是避免你順手加註解。
5. **一條測試失敗會中止它所在 suite 的剩餘測試。** 本檔若有多條測試,
   不要靠「跑一次全紅」證明任何東西。

## 交付與驗收

**這一輪只跑你自己那一支檔**(快,不會跟協調者的全套撞車):
```bash
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  -a tests/integration/ui/battle/battle_screen_real_level_battle_test.gd
```
⚠️ **務必檢查輸出的 `Executed test cases : (n/n)`** —— 本專案登記過「filter 打錯字會 exit 0、
零條測試執行、看起來像通過」。

**全套由協調者自己跑,不要重複。** 回報時貼出你那支 suite 的 `Statistics:` 原文,
並逐條寫明哪幾條你**實際看到 STARTED/PASSED**。
