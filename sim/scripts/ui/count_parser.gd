class_name CountParser
extends RefCounted
## Parses user-entered creature counts such as "5,000", "10k", "1.5k", "2m".

static var _plain := _compile("^\\d+$")
static var _grouped := _compile("^\\d{1,3}(,\\d{3})+$")
static var _suffixed := _compile("^(\\d+)(?:\\.(\\d))?([km])$")


static func _compile(pattern: String) -> RegEx:
	var re := RegEx.new()
	re.compile(pattern)
	return re


## Returns the count, or -1 if the text is not a valid positive whole count.
static func parse(text: String) -> int:
	var s := text.strip_edges().to_lower()
	var value := -1
	if _plain.search(s) != null or _grouped.search(s) != null:
		var digits := s.replace(",", "")
		if digits.length() > 18:
			return -1
		value = digits.to_int()
	else:
		var m := _suffixed.search(s)
		if m == null:
			return -1
		var whole := m.get_string(1)
		if whole.length() > 12:
			return -1
		var tenths := m.get_string(2).to_int()
		var unit := 1000 if m.get_string(3) == "k" else 1000000
		value = whole.to_int() * unit + tenths * unit / 10
	return value if value > 0 else -1
