# Story 001:對話正文字型入庫與引擎缺字檢查

> **Epic**: `production/epics/support-conversation-ui/EPIC.md`
> **Status**: Ready(2026-10-28)
> **Type**: Config/Data
> **依據**: 管理者 2026-10-28 裁決「先用霞鶩文楷做,回家看實際畫面再決定」;候選資料 `docs/reviews/dialogue-font-shortlist-2026-10-28.md`

## Acceptance Criteria

- [ ] **AC1 來源**:從官方來源(`github.com/lxgw/LxgwWenkaiTC` 的 Releases)取得**繁中版 Regular 一個字重**的 `.ttf`,記錄下載網址、版本號、檔案大小(bytes)、SHA-256。
- [ ] **AC2 授權以檔案本身為準**:授權全文取自同一 release 附帶的授權檔,不是網頁轉述。確認允許內嵌與再散布;記錄是否有 Reserved Font Name 宣告。**授權不允許 → 停下回報,不入庫。**
- [ ] **AC3 入庫**:字型檔放 `assets/fonts/`,授權全文放同目錄(檔名比照既有 `OFL.txt` 的做法,不得覆蓋它)。
- [ ] **AC4 引擎缺字檢查((A) 級)**:用引擎載入該字型,對 `design/narrative/support-conversations-script.md` 中**所有台詞與角色姓名的每一個字元**呼叫 `Font.has_char()`,另加「體、識、籲」三字;輸出缺字清單(期望為空)。檢查腳本放 `prototypes/dialogue-font-glyph-check-2026-10-28/`,附原始輸出檔。
- [ ] **AC5 檔案大小揭露**:若單檔 > 10 MB,回報並附「子集化」的可行性說明,**不自行子集化**。

## Affected Files

| 檔案 | 動作 |
|---|---|
| `assets/fonts/<字型檔>.ttf` + 授權檔 | 新增 |
| `prototypes/dialogue-font-glyph-check-2026-10-28/` | 新增 |
| `assets/fonts/README.md` | **文件 —— 不得直接改**,把要加的段落逐字交回協調者 |

## 限制

不開有視窗的 Godot。不改任何程式碼。
