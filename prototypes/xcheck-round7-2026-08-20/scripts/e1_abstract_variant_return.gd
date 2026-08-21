@abstract
class_name SpikeBareVariant extends RefCounted
# ROUND7 Probe E — E1(核心)。ADR-0004 機制一第 91 行 `read_file() -> Variant`
# 目前是外推:2026-08-20 spike 已測的五種 @abstract 裸簽章回傳型別
# (Array[T]/bool/float/void/Vector2,見
# prototypes/engine-verification-spike-2026-08-20/scripts/c1_bare_*.gd)不含
# Variant。本檔只測「裸簽章 @abstract func f() -> Variant」這一種形狀能否編譯,
# 刻意與 E2/E3/E4 分檔,理由同 runner_c.gd/runner_d.gd 建立的紀律:單一有編譯
# 風險的測項各自一檔,一項 Parse Error 不能連坐擋掉其他項。

@abstract
func read_something() -> Variant
