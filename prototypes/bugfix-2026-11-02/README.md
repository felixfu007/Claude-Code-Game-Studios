# bugfix-2026-11-02 —— 手把 A/B 對應探針

**用途**:修 `2ad617e`(手把 A/B 不作用於一般按鈕)時,`godot-specialist` 用來向引擎直接讀
`ui_accept` / `ui_cancel` / `battle_confirm` 三個動作實際綁了哪些輸入事件,並確認
`InputMap.event_is_action(<手把 A>, "ui_accept")` 的真值。

**假說**:手把 A 按不下一般按鈕,是因為 `ui_accept` 沒有綁手把 A(而非按鈕本身的焦點問題)。

**狀態**:已結案(concluded)。**發現**:修正後 `project.godot` 的 `ui_accept` 加手把 A、
`ui_cancel` 加手把 B,見 `2ad617e` 提交訊息;修正前的輸出未存檔(見下方 ⚠️)。

**拋棄式**:不被 `src/` 引用,修正後不再需要。保留只為讓 `2ad617e` 的判斷可重現。

**執行**(headless 即可,只讀設定不讀像素):

```
<Godot 主程式> --headless --path . -s res://prototypes/bugfix-2026-11-02/probe_ui_accept.gd
```

⚠️ 本 README 由協調者於 2026-11-04 補寫(文件缺口偵測 hook 提示);**當時的執行輸出未存檔**,
故本檔不宣稱修正前後各印出什麼 —— 要知道就當場跑。
