# 逐字照抄 ADR-0002 機制二的宣告(省略 pair_of(),本 spike 不需要它)。
# 刻意不簡化 —— 要驗的必須是 ADR 真的打算寫的形狀。
class_name AffinityTypes extends RefCounted

enum Character { CHARACTER_1, CHARACTER_2, CHARACTER_3, CHARACTER_4, CHARACTER_5 }

enum Pair {
	C1_C2, C1_C3, C1_C4, C1_C5,
	C2_C3, C2_C4, C2_C5,
	C3_C4, C3_C5,
	C4_C5,
}

enum Source { COMBAT_CARD, SUPPORT_CONVERSATION, STORY_EVENT }
