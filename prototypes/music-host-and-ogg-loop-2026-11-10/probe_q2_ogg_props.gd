extends SceneTree
const OGG := "C:/tmp/aiimg27/docs/team/deliveries/2026-11-07-music-candidates/candidates/mus_battle_main_loop_c01.ogg"
func _init() -> void:
	var fresh := AudioStreamOggVorbis.new()
	print("Q2 fresh: loop=", fresh.loop, " loop_offset=", fresh.loop_offset, " length=", fresh.get_length())
	var names: Array = []
	for p in fresh.get_property_list():
		if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE == 0 and p["name"] in ["loop","loop_offset","bpm","beat_count","bar_beats","packet_sequence","tags"]:
			names.append(p["name"])
	print("Q2 props: ", names)
	var s := AudioStreamOggVorbis.load_from_file(OGG)
	print("Q2 loaded null? ", s == null)
	if s != null:
		print("Q2 file: loop=", s.loop, " loop_offset=", s.loop_offset, " length=", s.get_length(), " bpm=", s.bpm)
		s.loop = true
		s.loop_offset = 1.5
		print("Q2 after set: loop=", s.loop, " loop_offset=", s.loop_offset)
	quit()
