# 語法變體:@abstract 與 func 寫在同一行。
# 參考庫範例把 @abstract 單獨放一行;若兩種都可以,ADR 就有選擇自由,
# 若只有一種可以,那一種必須寫進 ADR 而不是留給實作者猜。
@abstract
class_name SpikeInlineAbstractHost extends RefCounted

@abstract func inline_declared() -> bool
