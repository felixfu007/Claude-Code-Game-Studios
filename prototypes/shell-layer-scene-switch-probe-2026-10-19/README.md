# 殼層場景切換探針(2026-10-19)

**狀態**:✅ Concluded(2026-10-19)
**假設/用途**:做標題/設定畫面(game-shell epic)之前,量掉游標 Autoload 跨場景、表面註冊釋放、`change_scene_to_file()` 時機、來回切換四個從未實測過的引擎行為。
**執行者**:`godot-specialist`;README 由協調者 2026-10-27 補寫(補 session-start hook 回報的缺口)。
**方案書**:`docs/reviews/shell-layer-feasibility-2026-10-19.md`(133 行,四題答案 + 不寫 ADR 的理由)。

## 怎麼跑

```bash
"<Godot 4.7.1 console 執行檔>" --headless --path . -s prototypes/shell-layer-scene-switch-probe-2026-10-19/probe_scene_switch.gd
```

原始輸出:`run_output_headless.txt`(本目錄)。結構/狀態量測,headless 可跑,不涉及像素。
依 `technical-preferences.md` 第 5 點,`load()` 的是 production 的 `BattleScreen.tscn`,不是替身。

## 答案(逐字原始行在 `run_output_headless.txt`)

| 題 | 答案 | 原始行 |
|---|---|---|
| Q1 游標 Autoload 跨場景 | 同一實例,未重建,`_process` 未中斷 | `Q1-FINAL: instance_id=30484202971 same_as_original=true` |
| Q2 切走後 BOARD_TILE 有沒有釋放 | 有 | `Q2-AFTER-SWITCH: ... -> REGISTERED` |
| Q3 `change_scene_to_file()` 時機 | 混合:舊場景當場離樹、呼叫端下一行照跑、新場景 `_ready()` 延後 | `Q3-IMMEDIATELY-AFTER: ... is_inside_tree()=false`、`Q3-CALLER-CONTINUES` |
| Q4 來回切換 | 零錯誤,第二個 BattleScreen 乾淨重新佔住 BOARD_TILE | `Q4-BOARD-TILE: ... DUPLICATE_TAG_REJECTED` |

## 🔴 兩項讀這份輸出時必須知道的更正

1. **Q2 的 log 措辭「tree_exited 安全網成功解除了 BOARD_TILE」—— 判定對、理由錯**(2026-10-19 協調者查出)。
   註冊表**刻意不自動清理**;釋放靠的是 `battle_screen.gd` 自己手工接的 `tree_exited → unregister_surface`。
   ➜ **每個向游標註冊表面的新畫面都得自己接一條**(已寫成 `production/epics/game-shell/EPIC.md` 的全域義務)。
2. **production 已不再用 `change_scene_to_file()`**(2026-10-27,game-shell story-005)——
   它沒有資料注入時機窗,改由 `src/ui/shell/scene_router.gd` 手動做 `instantiate → 注入 → add_child`。
   **Q3 量到的時機描述的是舊做法**;新做法的交換是 `call_deferred`,呼叫端同樣要等幀才看到新場景。

## 未量測(方案書第二節已登記)

- 多個 Autoload 共存時的載入順序。
- ADR-0005 機制五(`_frame_events` / `_arbitration_suspended`)在切場景瞬間是否殘留。
