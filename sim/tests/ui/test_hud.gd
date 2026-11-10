extends GutTest

var hud: Hud

func before_each():
	hud = load("res://scenes/ui/hud.tscn").instantiate()
	add_child_autofree(hud)
	var list: Array[Dictionary] = [
		{"id": "flea", "name": "Flea"},
		{"id": "wasp", "name": "Wasp"},
	]
	hud.set_species(list)

func test_quick_buttons_set_field():
	hud.get_node("%Quick1k").emit_signal("pressed")
	assert_eq(hud.get_node("%CountEdit").text, "1k")
	hud.get_node("%Quick10").emit_signal("pressed")
	assert_eq(hud.get_node("%CountEdit").text, "10")
	hud.get_node("%Quick100").emit_signal("pressed")
	assert_eq(hud.get_node("%CountEdit").text, "100")
	hud.get_node("%Quick10k").emit_signal("pressed")
	assert_eq(hud.get_node("%CountEdit").text, "10k")

func test_add_emits_with_selected_species():
	watch_signals(hud)
	hud.get_node("%SpeciesOption").select(1)
	hud.get_node("%CountEdit").text = "1.5k"
	hud.get_node("%AddButton").emit_signal("pressed")
	assert_signal_emitted_with_parameters(hud, "add_requested", ["wasp", 1500])
	assert_false(hud.get_node("%ErrorLabel").visible)

func test_add_default_count_is_100():
	watch_signals(hud)
	hud.get_node("%AddButton").emit_signal("pressed")
	assert_signal_emitted_with_parameters(hud, "add_requested", ["flea", 100])

func test_add_invalid_shows_error_no_signal():
	watch_signals(hud)
	hud.get_node("%CountEdit").text = "abc"
	hud.get_node("%AddButton").emit_signal("pressed")
	assert_signal_not_emitted(hud, "add_requested")
	var err: Label = hud.get_node("%ErrorLabel")
	assert_true(err.visible)
	assert_eq(err.text, "Enter a whole number like 5000")

func test_counts_display_and_total():
	hud.set_counts({"flea": 5000, "wasp": 203}, {"flea": "Flea", "wasp": "Wasp"})
	var text: String = hud.get_node("%CountsLabel").text
	assert_string_contains(text, "Flea  5,000")
	assert_string_contains(text, "Wasp  203")
	assert_eq(hud.get_node("%TotalLabel").text, "Total 5,203")

func test_fps_label():
	hud.set_fps(59.6)
	assert_string_contains(hud.get_node("%FpsLabel").text, "60")

func test_clear_and_credits_signals():
	watch_signals(hud)
	hud.get_node("%ClearButton").emit_signal("pressed")
	hud.get_node("%CreditsButton").emit_signal("pressed")
	assert_signal_emitted(hud, "clear_requested")
	assert_signal_emitted(hud, "credits_requested")

func test_show_credits_modal():
	hud.show_credits("Models by someone")
	var panel: Control = hud.get_node("%CreditsPanel")
	assert_true(panel.visible)
	assert_eq(hud.get_node("%CreditsText").text, "Models by someone")
	hud.get_node("%CloseCredits").emit_signal("pressed")
	assert_false(panel.visible)

func test_root_ignores_mouse():
	assert_eq(hud.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(hud.get_node("%AddCard").mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(hud.get_node("%CounterCard").mouse_filter, Control.MOUSE_FILTER_STOP)

## Setting the text from code does not emit text_changed, so the quick buttons hide the
## error themselves once the field holds a valid count.
func test_quick_button_hides_error():
	hud.get_node("%CountEdit").text = "abc"
	hud.get_node("%AddButton").emit_signal("pressed")
	var err: Label = hud.get_node("%ErrorLabel")
	assert_true(err.visible)
	hud.get_node("%Quick1k").emit_signal("pressed")
	assert_false(err.visible)
