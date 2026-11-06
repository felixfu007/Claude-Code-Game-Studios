# Epic: 音訊基礎(audio-foundation)

> **Status**: Draft(2026-11-06 起草,待協調者核可後派工;story-001 已解除阻擋)
> **來源**: `docs/reviews/minimal-audio-scope-draft-2026-11-06.md` 第二、四節
> **管理者裁決**: 2026-11-06「要,現在就先做程式骨架(推薦)」;素材來源「混合:音效用免費無權利素材,音樂用 AI 產」,素材尚未到。

## Overview

遊戲目前 `src/` 完全沒有音訊程式。本 epic 只做**程式骨架**:AudioBus 結構、主音量/音樂/音效三滑桿加靜音(存檔)、訂閱既有 signal 的音效播放服務(M1~M9),以及可選的音樂播放。素材缺席時一切安靜無錯,素材到位後放入約定路徑即生效。**不含素材取得、授權登記、試聽驗收(家中進行)。**

## Stories

| # | Story | Type | 前置 | 狀態 |
|---|---|---|---|---|
| 001 | `story-001-audio-bus-and-volume-settings.md` — Bus、音量/靜音、設定檔持久化(含 EGM 與隱藏好感度) | Logic | 無 | Ready |
| 002 | `story-002-settings-screen-volume-controls.md` — 設定畫面三滑桿 + 靜音 | UI | 001 | Blocked(待 001) |
| 003 | `story-003-sfx-cue-service.md` — 音效 cue 服務(M1~M9) | Logic+Integration | 001 | Blocked(待 001) |
| 004 | `story-004-music-playback.md` — 音樂播放(可選) | Logic+Integration | 001、003 | Blocked,可延後 |

## 架構立場

- **不需要跨系統契約 ADR**:音訊是單向訂閱既有 signal,無共用狀態契約;設定存檔不是遊戲存檔。若實作中發現必須新增跨系統契約,停下回報。
- **預設不新增 Autoload**(001~003)。story-004 可能需要,屆時須同步更新 `technical-preferences.md` Autoload 表(文件,需請示)並跑全套;`class_name` 不可與 Autoload 同名。
- **依賴方向**:`src/gameplay/**` 不得依賴音訊;決策邏輯為可 `new()` 的 `RefCounted`,播放殼為薄 `Node`;headless 只驗決策,不斷言「真的響了」。
- **引擎 API 皆標未驗證**:`AudioServer` / bus / `linear_to_db` / `ConfigFile` / `ResourceLoader.exists` / `HSlider` 手把操作,實作者須以 `docs/engine-reference/godot/` 或 headless 探針確認。

## 已裁決/已定案(2026-11-06)

- 🔴 管理者裁決:做一個小設定檔(`user://settings.cfg`,`ConfigFile`),**音量與既有兩個開關(EGM、隱藏好感度)都記住**。推翻 `game-shell/story-002` 的「不做跨啟動持久化」。
- 單元測試不寫檔:編解碼走純函式測試,檔案薄殼以探針實跑留 log。
- 啟動接點:`TitleScreen._ready()`(`project.godot` 開機場景),不用 Autoload。測試污染防法見 story-001。
- M1 按鈕音效接線:場景級宿主走訪 `BaseButton`,見 story-003。

## Open Questions

1. 預設音量數值為未驗證初值,家中實聽後調整。
2. story-004 的常駐宿主是否用 Autoload。
3. 探針結果若推翻 story-001 的假設(headless 判斷、`ConfigFile` 往返),停下回報。

## Out of Scope

素材取得、素材授權登記、遊戲內署名頁、AI 音訊揭露政策(草案 Q6),不在本 epic。
