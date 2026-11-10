class_name Hud
extends Control
## Floating-card HUD. The root ignores the mouse so camera drags pass through;
## only the cards (and the credits modal) block it.

signal add_requested(species_id: String, count: int)
signal clear_requested()
signal credits_requested()

const ERROR_TEXT := "Enter a whole number like 5000"

@onready var _species: OptionButton = %SpeciesOption
@onready var _count_edit: LineEdit = %CountEdit
@onready var _error: Label = %ErrorLabel
@onready var _counts: Label = %CountsLabel
@onready var _total: Label = %TotalLabel
@onready var _fps: Label = %FpsLabel
@onready var _credits_panel: Control = %CreditsPanel
@onready var _credits_text: RichTextLabel = %CreditsText


func _ready() -> void:
	for pair in [["%Quick10", "10"], ["%Quick100", "100"], ["%Quick1k", "1k"], ["%Quick10k", "10k"]]:
		var text: String = pair[1]
		get_node(pair[0]).pressed.connect(func() -> void: _count_edit.text = text)
	%AddButton.pressed.connect(_on_add_pressed)
	%ClearButton.pressed.connect(func() -> void: clear_requested.emit())
	%CreditsButton.pressed.connect(func() -> void: credits_requested.emit())
	%CloseCredits.pressed.connect(func() -> void: _credits_panel.hide())
	_count_edit.text_changed.connect(func(_t: String) -> void: _error.hide())
	_count_edit.text_submitted.connect(func(_t: String) -> void: _on_add_pressed())
	_error.text = ERROR_TEXT
	_error.hide()
	_credits_panel.hide()


func set_species(list: Array[Dictionary]) -> void:
	_species.clear()
	for entry in list:
		_species.add_item(str(entry.get("name", entry.get("id", ""))))
		_species.set_item_metadata(_species.item_count - 1, str(entry.get("id", "")))
	if _species.item_count > 0:
		_species.select(0)


func set_counts(counts: Dictionary, names: Dictionary) -> void:
	var lines: PackedStringArray = []
	var total := 0
	for id in counts:
		var n: int = counts[id]
		total += n
		lines.append("%s  %s" % [names.get(id, id), _fmt(n)])
	_counts.text = "\n".join(lines)
	_total.text = "Total %s" % _fmt(total)


func set_fps(fps: float) -> void:
	_fps.text = "FPS %d" % roundi(fps)


func show_credits(text: String) -> void:
	_credits_text.text = text
	_credits_panel.show()


func _on_add_pressed() -> void:
	var n := CountParser.parse(_count_edit.text)
	if n < 0 or _species.item_count == 0:
		_error.show()
		return
	_error.hide()
	add_requested.emit(str(_species.get_item_metadata(_species.selected)), n)


static func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
