extends SceneTree
## Loads the raw TTF (no import needed) and calls Font.has_char() on every char.
const FONT_PATH := "res://assets/fonts/LXGWWenKaiTC-Regular.ttf"
const SCRIPT_PATH := "res://design/narrative/support-conversations-script.md"
const EXTRA := "藍亭萱徐培恩董振豪秦亦柔麥子健體識籲"  # 5 names (literal) + three chars

func _init() -> void:
	var ff := FontFile.new()
	var err := ff.load_dynamic_font(ProjectSettings.globalize_path(FONT_PATH))
	print("load_dynamic_font err=", err, " font_name=", ff.get_font_name(), " style=", ff.get_font_style_name())
	var chars := {}
	var lines := 0
	for line in FileAccess.get_file_as_string(SCRIPT_PATH).split("\n"):
		var l := line.strip_edges()
		if l.length() > 2 and l[1] == ":" or l.length() > 2 and l[1] == "\uFF1A":
			if "甲乙丙丁".contains(l[0]):
				lines += 1
				for c in l.substr(2):
					chars[c] = true
	print("dialogue lines=", lines, " distinct dialogue chars=", chars.size())
	for c in EXTRA:
		chars[c] = true
	var missing := ""
	for c in chars.keys():
		if not ff.has_char(c.unicode_at(0)):
			missing += c
	print("TOTAL distinct checked=", chars.size())
	print("MISSING count=", missing.length(), " list=[", missing, "]")
	# supplementary: every non-ASCII char in whole script file
	var all_missing := ""
	var all_n := 0
	var seen := {}
	for c in FileAccess.get_file_as_string(SCRIPT_PATH):
		if c.unicode_at(0) > 127 and not seen.has(c):
			seen[c] = true
			all_n += 1
			if not ff.has_char(c.unicode_at(0)):
				all_missing += c
	print("SUPPLEMENTARY whole-file non-ASCII distinct=", all_n, " missing=[", all_missing, "]")
	quit()
