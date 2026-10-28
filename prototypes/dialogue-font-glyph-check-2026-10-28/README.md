# 對話正文字型缺字檢查(霞鶩文楷 TC Regular)

狀態:concluded(2026-10-28)

## 目的
Story 001:字型入庫並以引擎 `Font.has_char()` 檢查劇本全部台詞與姓名字元(AC4)。

## 來源
- 下載網址:https://github.com/lxgw/LxgwWenkaiTC/releases/download/v1.530/LXGWWenKaiTC-Regular.ttf
- 版本 v1.530(發布 2026-10-17)
- 15341148 bytes;SHA-256 `6662480a3f95b4a90c80b189c679617a48adce3a505118a6af63ce5a482b83fa`(與 GitHub release API 的 digest 一致)
- 授權:release zip 內 `OFL.txt`,SHA-256 與 repo 根目錄 OFL.txt 相同(`1a13783b...db9d174def`)

## 步驟
`"<godot>" --headless --path . -s res://prototypes/dialogue-font-glyph-check-2026-10-28/glyph_check.gd`
腳本用 `FontFile.load_dynamic_font()` 直接讀原檔(不經匯入),對劇本 39 行台詞(甲乙丙丁行)、
5 個姓名、「體識籲」共 213 個相異字元呼叫 `has_char()`。

## 結果
缺字 0。原始輸出見 `run_output.txt`。附帶(非 AC 範圍):全檔非 ASCII 字元唯一缺的是文件標記 emoji 🔴,不是台詞。
