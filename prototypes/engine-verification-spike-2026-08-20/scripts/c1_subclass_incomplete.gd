# ADR-0004 VR #6a:具體子類別**故意漏實作** diagnostic_seed_position()。
#
# 問題:漏實作是編譯期錯誤,還是要等該方法被實際呼叫才在執行期顯現?
# 這一項直接決定 ADR-0004/0005 對「@abstract 保證子類別必須實作」這個宣稱能不能成立 ——
# 若只在執行期顯現,那個保證就只是「呼叫到才會爆」,不是結構保證。
#
# 本檔只被 load(),不被實例化。load() 成功與否就是答案。
extends SpikeBareWithSignal   # 刻意不給 class_name,理由同上

func evaluate(_current_mouse_position: Vector2) -> bool:
	return true
# diagnostic_seed_position() 刻意不實作
