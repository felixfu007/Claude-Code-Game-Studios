class_name AffinityTypes extends RefCounted
# 逐位元組取自 docs/architecture/adr-0002-... 機制二的宣告(僅供本次探針使用,
# 非本 ADR 的權威版本 —— 見該文件本體)。

enum Character { CHARACTER_1, CHARACTER_2, CHARACTER_3, CHARACTER_4, CHARACTER_5 }

enum Pair {
	C1_C2, C1_C3, C1_C4, C1_C5,
	C2_C3, C2_C4, C2_C5,
	C3_C4, C3_C5,
	C4_C5,
}

enum Source { COMBAT_CARD, SUPPORT_CONVERSATION, STORY_EVENT }
