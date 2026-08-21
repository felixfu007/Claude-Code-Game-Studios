@abstract
class_name SaveIOBackend extends RefCounted
# ROUND7 Probe E — E3(最高價值)。ADR-0004 機制一 SaveIOBackend 逐字編譯測試
# (docs/architecture/adr-0004-save-system-atomic-write-and-migration-execution-model.md
# 第 73-92 行)。唯一的修正是刪掉冒號 + `pass` 主體 —— 2026-08-20 spike 的
# c1_bare_with_signal.gd 等五個對照組已確認裸簽章才是正確語法,冒號+pass 是
# `Parse Error: An abstract function cannot have a body.`(該修正是本次委派
# brief 明文交代要先做的,不是本探針自行決定)。
#
# 本檔混合 bool x4 + Variant x1、且 @abstract 標記與 class_name/extends 同檔 ——
# 這是 ADR 真正要寫下去的組合。單獨測各回傳型別(E1/E2)不等於測這個組合:
# 例如 @abstract 類別內同時有多個不同回傳型別的抽象方法,理論上可能觸發與單一
# 方法測試不同的解析路徑(未查證,故仍需本檔逐字驗證,不可只憑 E1/E2 通過就外推)。

@abstract
func write_temp(path: String, buffer: PackedByteArray) -> bool   # Core Rules #14 Step 1
@abstract
func rename_file(from_path: String, to_path: String) -> bool     # Step 2/3/4
@abstract
func delete_file(path: String) -> bool                            # Step 4a
@abstract
func file_exists(path: String) -> bool
@abstract
func read_file(path: String) -> Variant                           # PackedByteArray 或 null(不存在/讀取失敗)
