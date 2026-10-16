# `ui_*` 動作與裝置分類探針(Story 004,2026-09-03)

**這不是試作,是一支一次性的量測探針。** 2026-10-16 補寫 README —— 當時只留了程式與 log,
每次 session 啟動檢查都會把它報成「未文件化的試作」。

## 它回答什麼

ADR-0005 機制四之二明文把 `ACKNOWLEDGED_OTHER_ACTIONS` 的列舉值寫成
「a reference starting point — implementation must fill it in against the real InputMap contents」。

**而本專案的 `project.godot` 只自訂了 `battle_*` 系列、沒有自訂任何 `ui_*`** ——
所以那些 `ui_*` 動作全部來自 Godot 4.7.1 引擎自己註冊的預設值。
**除了問正在跑的引擎,沒有別的方法知道那一組到底有哪些。**

## 證據等級:(A)

引擎執行的是專案釘死的那一版,讀的是引擎自己的 `InputMap`,**不是重新實作一份清單**。

## 檔案

| 檔案 | 是什麼 |
|---|---|
| `probe_ui_actions.gd` | 探針本體。**目的、依據與它證明不了什麼都在它的檔頭**,本 README 不複述 |
| `logs/` | 原始輸出 |
