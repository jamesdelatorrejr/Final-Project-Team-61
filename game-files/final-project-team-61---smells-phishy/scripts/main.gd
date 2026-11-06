extends Control
## Day-one vertical slice. All links and attachments are inspection-only.

const ShiftRules = preload("res://scripts/shift.gd")
const INK := Color("182b3a")
const BLUE := Color("294f70")
const GREEN := Color("477a58")
const RED := Color("a64b4b")
const GOLD := Color("d3a82b")
const INFO_BLUE := Color("3f789e")
const FILE_PURPLE := Color("6d5a83")
const PAPER := Color("b9cbd1")
const LIGHT_PAPER := Color("e9e7d8")
const SAVE_PATH := "user://shift_save.cfg"
const SETTINGS_PATH := "user://audio_settings.cfg"
var shift
var page: VBoxContainer
var clock_label: Label
var status_label: Label
var strike_dots: Array[PanelContainer] = []
var inbox: VBoxContainer
var reader: VBoxContainer
var feedback: Label
var continue_button: Button
var approve: Button
var quarantine: Button
var selected := -1
var working := false
var awaiting_feedback := false
var checkpoint := false
var feedback_overlay: Control
var exit_overlay: Control
var creators_overlay: Control
var ui_audio: AudioStreamPlayer
var sounds: Dictionary = {}
var sound_volume := 1.0
var interface_bold_font: FontVariation

func _ready() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("101d28")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var shell := PanelContainer.new()
	shell.add_theme_stylebox_override("panel", panel_style(PAPER))
	margin.add_child(shell)
	page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	shell.add_child(page)
	var app_theme := Theme.new()
	# Godot's bundled sans font keeps dense training content easy to read.
	app_theme.default_font_size = 18
	interface_bold_font = FontVariation.new()
	interface_bold_font.base_font = ThemeDB.fallback_font
	interface_bold_font.variation_embolden = 0.75
	app_theme.set_font("font", "Button", interface_bold_font)
	app_theme.set_font("bold_font", "RichTextLabel", interface_bold_font)
	app_theme.set_color("font_color", "Label", INK)
	app_theme.set_color("font_color", "Button", Color("f7f2df"))
	app_theme.set_color("font_hover_color", "Button", Color("fff8dc"))
	app_theme.set_color("font_focus_color", "Button", Color("fff8dc"))
	app_theme.set_color("font_pressed_color", "Button", Color.WHITE)
	app_theme.set_color("font_disabled_color", "Button", Color("899ba3"))
	app_theme.set_stylebox("normal", "Button", panel_style(BLUE))
	app_theme.set_stylebox("hover", "Button", panel_style(Color("3b6788")))
	app_theme.set_stylebox("pressed", "Button", panel_style(INK))
	app_theme.set_stylebox("disabled", "Button", panel_style(Color("6f7f85")))
	var focus := panel_style(Color.TRANSPARENT)
	focus.set_border_width_all(3)
	focus.border_color = Color("7fc1e3")
	app_theme.set_stylebox("focus", "Button", focus)
	theme = app_theme
	ui_audio = AudioStreamPlayer.new()
	add_child(ui_audio)
	sounds = {
		# Hover is 90% quieter and click is 50% quieter than the prior mix.
		"move": make_tone(520.0, 0.035, 0.01),
		"click": make_tone(690.0, 0.055, 0.065),
		"good": make_tone(880.0, 0.11, 0.14),
		"bad": make_tone(180.0, 0.14, 0.14),
	}
	load_audio_settings()
	apply_audio_settings()
	checkpoint = FileAccess.file_exists(SAVE_PATH)
	show_menu()

func panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.set_corner_radius_all(0)
	style.set_border_width_all(3)
	style.border_color = color.darkened(0.35)
	style.border_width_bottom = 6
	style.anti_aliasing = false
	return style

func card_style(color: Color, border := INK) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.set_border_width_all(3)
	style.border_color = border
	style.set_corner_radius_all(0)
	style.anti_aliasing = false
	return style

func dot_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(2)
	style.set_border_width_all(2)
	style.border_color = color.darkened(0.3)
	style.anti_aliasing = false
	return style

func card_into(parent: Node, color := LIGHT_PAPER, border := INK) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", card_style(color, border))
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 5)
	panel.add_child(content)
	return content

func expand_card(content: VBoxContainer, minimum_height: float) -> void:
	var panel := content.get_parent() as PanelContainer
	if panel == null:
		return
	panel.custom_minimum_size.y = minimum_height
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.alignment = BoxContainer.ALIGNMENT_CENTER

func metric_card(parent: Node, caption: String, value: String, accent := BLUE) -> void:
	var content := card_into(parent, LIGHT_PAPER, accent)
	(content.get_parent() as PanelContainer).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := bold_label_into(content, caption, 13)
	title.add_theme_color_override("font_color", accent)
	bold_label_into(content, value, 22)

func make_tone(frequency: float, duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in range(sample_count):
		var fade := 1.0 - float(i) / float(sample_count)
		var sample := int(sin(TAU * frequency * float(i) / sample_rate) * 32767.0 * volume * fade)
		data.encode_s16(i * 2, sample)
	var tone := AudioStreamWAV.new()
	tone.format = AudioStreamWAV.FORMAT_16_BITS
	tone.mix_rate = sample_rate
	tone.stereo = false
	tone.data = data
	return tone

func audio_db(value: float) -> float:
	return -80.0 if value <= 0.001 else linear_to_db(value)

func apply_audio_settings() -> void:
	if ui_audio != null:
		ui_audio.volume_db = audio_db(sound_volume)

func load_audio_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		sound_volume = clampf(float(config.get_value("audio", "sound", 1.0)), 0.0, 1.0)

func save_audio_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "sound", sound_volume)
	config.save(SETTINGS_PATH)

func play_ui(kind: String) -> void:
	if sound_volume <= 0.001 or ui_audio == null or not sounds.has(kind):
		return
	ui_audio.stream = sounds[kind]
	ui_audio.play()

func clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func label_into(parent: Node, value: String, font_size := 19) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func bold_label_into(parent: Node, value: String, font_size := 19) -> Label:
	var label := label_into(parent, value, font_size)
	if interface_bold_font != null:
		label.add_theme_font_override("font", interface_bold_font)
	return label

func button_into(parent: Node, value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 54
	button.add_theme_font_size_override("font_size", 20)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func():
		play_ui("click")
		action.call()
	)
	button.mouse_entered.connect(play_ui.bind("move"))
	button.focus_entered.connect(play_ui.bind("move"))
	parent.add_child(button)
	return button

func rich_into(parent: Node, value: String, font_size := 19) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.text = value
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_color_override("default_color", INK)
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_font_size_override("bold_font_size", font_size)
	label.add_theme_constant_override("line_separation", 2)
	parent.add_child(label)
	return label

func color_action(button: Button, color: Color) -> void:
	button.add_theme_stylebox_override("normal", panel_style(color))
	button.add_theme_stylebox_override("hover", panel_style(color.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", panel_style(color.darkened(0.18)))

func heading() -> void:
	var bar := PanelContainer.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("panel", card_style(Color("244b6b"), Color("0e2638")))
	page.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)
	var title := bold_label_into(row, "SMELLS PHISHY.", 15)
	title.add_theme_color_override("font_color", Color("f3f1df"))
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var controls := label_into(row, "[ - ] [ ] [ X ]", 13)
	controls.add_theme_color_override("font_color", Color("d7e1e2"))
	controls.autowrap_mode = TextServer.AUTOWRAP_OFF

func show_briefing() -> void:
	checkpoint = true
	working = false
	awaiting_feedback = false
	selected = -1
	clear_children(page)
	shift = ShiftRules.new()
	if shift.load_content() != OK:
		heading()
		label_into(page, "Could not load data/day_01.json. Check the scenario fields and JSON syntax.")
		return
	heading()
	var briefing_scroll := ScrollContainer.new()
	briefing_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	briefing_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(briefing_scroll)
	var briefing := VBoxContainer.new()
	briefing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	briefing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	briefing.custom_minimum_size.y = 520
	briefing.add_theme_constant_override("separation", 6)
	briefing_scroll.add_child(briefing)
	rich_into(briefing, "[b]Welcome to your first shift.[/b]", 30)
	rich_into(briefing, "[b]FROM:[/b] Morgan, Security Supervisor", 17)
	var mission := card_into(briefing, LIGHT_PAPER, BLUE)
	expand_card(mission, 92)
	rich_into(mission, "[b]YOUR JOB[/b]", 20)
	rich_into(mission, "Review [b]8 forwarded emails[/b]. Choose [b]APPROVE[/b] for legitimate mail or [b]QUARANTINE[/b] for phishing.", 20)
	var notes := card_into(briefing, Color("dce4e4"), INK)
	expand_card(notes, 176)
	rich_into(notes, "[b]CHECK BEFORE YOU DECIDE[/b]", 20)
	rich_into(notes, "1. Find the colored tags beside email details: [color=#3d6f8e][b]S[/b][/color] sender, [color=#9b7620][b]L[/b][/color] link, [color=#74527c][b]F[/b][/color] file.\n2. [b]Hover a tag[/b] to reveal its real address, destination, or filename. Click to keep it open.\n3. Compare the evidence with [b]smellsphishy.example[/b], then judge the request and context.", 19)
	var requirements := card_into(briefing, Color("dce8dc"), GREEN)
	expand_card(requirements, 126)
	rich_into(requirements, "[b]PASS THE SHIFT[/b]", 20)
	rich_into(requirements, "Review [b]all 8 emails[/b] with at least [b]75% accuracy[/b]. [b]3 mistakes[/b] end the shift. The 9 AM-5 PM clock lasts [b]5 real minutes[/b] and pauses during coaching.", 19)
	button_into(page, "ACKNOWLEDGE / OPEN TRAINING MEMO >", show_training).grab_focus()

func start_shift() -> void:
	if shift == null:
		shift = ShiftRules.new()
		shift.load_content()
	clear_children(page)
	heading()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	page.add_child(top)
	status_label = bold_label_into(top, "", 18)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var strikes_title := bold_label_into(top, "STRIKES", 16)
	strikes_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	strikes_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	strikes_title.custom_minimum_size.x = 72
	var dots := HBoxContainer.new()
	dots.add_theme_constant_override("separation", 7)
	top.add_child(dots)
	strike_dots.clear()
	for i in range(3):
		var dot := PanelContainer.new()
		dot.custom_minimum_size = Vector2(16, 16)
		dot.add_theme_stylebox_override("panel", dot_style(Color("72838b")))
		dots.add_child(dot)
		strike_dots.append(dot)
	clock_label = bold_label_into(top, "09:00 AM", 22)
	clock_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	clock_label.custom_minimum_size.x = 140
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var exit_button := button_into(top, "X", prompt_exit)
	exit_button.tooltip_text = "Save shift and go home"
	exit_button.custom_minimum_size = Vector2(52, 48)
	exit_button.add_theme_font_size_override("font_size", 22)
	color_action(exit_button, RED)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(columns)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 380
	columns.add_child(sidebar)
	bold_label_into(sidebar, "INBOX", 18)
	var queue_scroll := ScrollContainer.new()
	queue_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	queue_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar.add_child(queue_scroll)
	inbox = VBoxContainer.new()
	inbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_scroll.add_child(inbox)
	rich_into(sidebar, "[b]KNOWN DOMAIN:[/b]  [b]smellsphishy.example[/b]", 14)
	var reading_scroll := ScrollContainer.new()
	reading_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reading_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var paper := PanelContainer.new()
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paper.add_theme_stylebox_override("panel", panel_style(Color("dce4e4")))
	columns.add_child(paper)
	paper.add_child(reading_scroll)
	reader = VBoxContainer.new()
	reader.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reader.add_theme_constant_override("separation", 7)
	reading_scroll.add_child(reader)
	feedback = label_into(page, "Select a message.", 16)
	feedback.custom_minimum_size.y = 22
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	page.add_child(actions)
	approve = button_into(actions, "[ APPROVE ]", decide.bind(false))
	quarantine = button_into(actions, "[ QUARANTINE ]", decide.bind(true))
	color_action(approve, GREEN)
	color_action(quarantine, RED)
	approve.custom_minimum_size = Vector2(220, 58)
	quarantine.custom_minimum_size = Vector2(245, 58)
	continue_button = button_into(actions, "CONTINUE >", advance)
	continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	continue_button.visible = false
	working = true
	refresh_inbox()
	show_inbox()
	update_status()

func refresh_inbox() -> void:
	clear_children(inbox)
	var active: Array[int] = []
	var filed: Array[int] = []
	for i in range(shift.emails.size()):
		if shift.decisions.has(i):
			filed.append(i)
		else:
			active.append(i)
	for group in [{"title": "ACTIVE", "items": active}, {"title": "FILED", "items": filed}]:
		if group.items.is_empty():
			continue
		var section := bold_label_into(inbox, group.title, 14)
		section.add_theme_color_override("font_color", Color("4d6069"))
		for i in group.items:
			var email: Dictionary = shift.emails[i]
			var prefix := "FILED / " if shift.decisions.has(i) else "FW: "
			var button := button_into(inbox, prefix + email.sender + "\n" + email.subject, select_email.bind(i))
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.custom_minimum_size = Vector2(360, 66)
			button.add_theme_font_size_override("font_size", 16)
			button.add_theme_font_override("font", interface_bold_font)
			button.disabled = shift.decisions.has(i) or awaiting_feedback

func plain_email_field(parent: Node, caption: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var field_name := bold_label_into(row, caption, 14)
	field_name.custom_minimum_size.x = 86
	field_name.add_theme_color_override("font_color", Color("4d6069"))
	var field_value := bold_label_into(row, value, 16)
	field_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func inspection_field(parent: Node, caption: String, value: String, code: String, accent: Color, detail: String) -> Button:
	var block := VBoxContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", 3)
	parent.add_child(block)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	block.add_child(row)
	var field_name := bold_label_into(row, caption, 14)
	field_name.custom_minimum_size.x = 86
	field_name.add_theme_color_override("font_color", Color("4d6069"))
	var field_value := bold_label_into(row, value, 16)
	field_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var evidence_panel := PanelContainer.new()
	evidence_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	evidence_panel.add_theme_stylebox_override("panel", card_style(Color("172a3a"), accent))
	var evidence := rich_into(evidence_panel, "[b]" + detail + "[/b]", 15)
	evidence.add_theme_color_override("default_color", Color("fff6d0"))
	evidence_panel.visible = false
	var button := Button.new()
	button.text = code
	button.tooltip_text = "Hover to inspect " + caption.to_lower()
	button.custom_minimum_size = Vector2(42, 34)
	button.add_theme_font_size_override("font_size", 16)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.set_meta("pinned", false)
	button.set_meta("evidence", evidence_panel)
	color_action(button, accent)
	button.mouse_entered.connect(func():
		play_ui("move")
		evidence_panel.visible = true
	)
	button.mouse_exited.connect(func():
		if not bool(button.get_meta("pinned")) and not button.has_focus():
			evidence_panel.visible = false
	)
	button.focus_entered.connect(func():
		play_ui("move")
		evidence_panel.visible = true
	)
	button.focus_exited.connect(func():
		if not bool(button.get_meta("pinned")):
			evidence_panel.visible = false
	)
	button.pressed.connect(func():
		play_ui("click")
		var pinned := not bool(button.get_meta("pinned"))
		button.set_meta("pinned", pinned)
		evidence_panel.visible = pinned or button.has_focus()
	)
	row.add_child(button)
	block.add_child(evidence_panel)
	return button

func select_email(index: int) -> void:
	if awaiting_feedback or shift.decisions.has(index):
		return
	selected = index
	(reader.get_parent() as ScrollContainer).scroll_vertical = 0
	clear_children(reader)
	var email: Dictionary = shift.emails[index]
	var back := button_into(reader, "< INBOX", show_inbox)
	back.custom_minimum_size.y = 42
	back.add_theme_font_size_override("font_size", 17)
	var mail := card_into(reader, Color("f0eddc"), INK)
	(mail.get_parent() as PanelContainer).custom_minimum_size.y = 430
	mail.add_theme_constant_override("separation", 9)
	var mail_title := bold_label_into(mail, "FORWARDED EMAIL", 13)
	mail_title.add_theme_color_override("font_color", BLUE)
	inspection_field(mail, "FROM", email.sender, "S", INFO_BLUE, "ACTUAL SENDER\n" + email.address + "\n\nKNOWN DOMAIN\nsmellsphishy.example")
	plain_email_field(mail, "TO", "Security Review Desk")
	plain_email_field(mail, "SUBJECT", email.subject)
	mail.add_child(HSeparator.new())
	rich_into(mail, "[b]MESSAGE[/b]\n" + email.body, 18)
	if not email.link_label.is_empty():
		inspection_field(mail, "LINK", email.link_label, "L", GOLD, "ACTUAL DESTINATION\n" + email.link_target + "\n\nCompare the destination with the visible link and known domain.")
	if not email.attachment.is_empty():
		inspection_field(mail, "FILE", "View attachment", "F", FILE_PURPLE, "FULL FILENAME\n" + email.attachment + "\n\nRead the final extension. This training file never opens.")
	approve.disabled = false
	quarantine.disabled = false

func decide(is_quarantine: bool) -> void:
	if awaiting_feedback or not working:
		return
	var result: Dictionary = shift.decide(selected, is_quarantine)
	if result.is_empty():
		return
	awaiting_feedback = true
	approve.disabled = true
	quarantine.disabled = true
	feedback.text = "Decision recorded."
	feedback.add_theme_color_override("font_color", GREEN if result.correct else RED)
	continue_button.text = "VIEW SHIFT REPORT >" if shift.finished() else "NEXT MESSAGE >"
	continue_button.visible = true
	continue_button.grab_focus()
	show_feedback(result.correct)
	refresh_inbox()
	update_status()

func advance() -> void:
	if is_instance_valid(feedback_overlay):
		remove_child(feedback_overlay)
		feedback_overlay.queue_free()
		feedback_overlay = null
	if shift.finished():
		show_summary()
		return
	awaiting_feedback = false
	continue_button.visible = false
	feedback.text = "Select the next message."
	feedback.add_theme_color_override("font_color", INK)
	refresh_inbox()
	show_inbox()

func _process(delta: float) -> void:
	if not working or awaiting_feedback:
		return
	shift.elapsed = minf(shift.elapsed + delta, ShiftRules.DURATION)
	shift.decision_seconds += delta
	update_status()
	if shift.finished():
		show_summary()

func update_status() -> void:
	status_label.text = "DAY 01   |   SCORE %03d" % (shift.correct * 100)
	for i in range(strike_dots.size()):
		var color := RED if i < shift.strikes else Color("72838b")
		strike_dots[i].add_theme_stylebox_override("panel", dot_style(color))
	var minutes := 9 * 60 + int(shift.elapsed / ShiftRules.DURATION * 480)
	var hour := minutes / 60
	clock_label.text = "%02d:%02d %s" % [((int(hour) + 11) % 12) + 1, minutes % 60, "AM" if hour < 12 else "PM"]

func show_summary() -> void:
	working = false
	clear_save()
	clear_children(page)
	heading()
	var reason := "You met today's quota and accuracy target."
	if not shift.passed():
		if shift.strikes >= ShiftRules.MAX_STRIKES:
			reason = "Three strikes ended your shift. Review the evidence and retry Day 1."
		elif shift.decisions.size() < shift.emails.size():
			reason = "It's 5 PM. You did not finish today's email quota."
		else:
			reason = "Your accuracy fell below the required 75%."
	var result_color := Color("dce6cc") if shift.passed() else Color("ead0c8")
	var result_border := GREEN if shift.passed() else RED
	var result_card := card_into(page, result_color, result_border)
	var result_title := bold_label_into(result_card, "SHIFT PASSED" if shift.passed() else "SHIFT UNSUCCESSFUL", 27)
	result_title.add_theme_color_override("font_color", result_border)
	bold_label_into(result_card, reason, 18)
	var metrics := HBoxContainer.new()
	metrics.add_theme_constant_override("separation", 8)
	page.add_child(metrics)
	metric_card(metrics, "REVIEWED", "%d / %d" % [shift.decisions.size(), shift.emails.size()])
	metric_card(metrics, "ACCURACY", "%.0f%%" % (shift.accuracy() * 100.0))
	metric_card(metrics, "SCORE", "%03d" % (shift.correct * 100))
	metric_card(metrics, "STRIKES", "%d / 3" % shift.strikes, RED if shift.strikes > 0 else GREEN)
	var seconds := 0.0
	for result in shift.decisions.values():
		seconds += result.seconds
	label_into(page, "False positives: %d | Missed phishing: %d | Average review: %.1f sec" % [shift.false_positives, shift.missed_phishing, seconds / maxi(1, shift.decisions.size())], 14)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var reviews := VBoxContainer.new()
	reviews.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reviews.add_theme_constant_override("separation", 8)
	scroll.add_child(reviews)
	for index in shift.decisions:
		var email: Dictionary = shift.emails[index]
		var result: Dictionary = shift.decisions[index]
		var review_color := Color("dce6cc") if result.correct else Color("ead0c8")
		var review_border := GREEN if result.correct else RED
		var review := card_into(reviews, review_color, review_border)
		var review_title := bold_label_into(review, ("CORRECT | " if result.correct else "REVIEW | ") + email.subject, 18)
		review_title.add_theme_color_override("font_color", review_border)
		rich_into(review, "[b]" + ("PHISHING | " if email.phishing else "LEGITIMATE | ") + "[/b]" + email.explanation, 15)
	if shift.passed():
		button_into(page, "RETURN TO MAIN MENU", show_menu).grab_focus()
	else:
		button_into(page, "VIEW EMPLOYMENT NOTICE >", show_termination).grab_focus()

func document(title: String) -> VBoxContainer:
	working = false
	clear_children(page)
	heading()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.custom_minimum_size.y = 520
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	rich_into(body, "[b]" + title + "[/b]", 34)
	return body

func office_into(parent: Node, portrait := false) -> Control:
	var art := Control.new()
	art.set_script(preload("res://scripts/office_art.gd"))
	art.portrait = portrait
	art.custom_minimum_size = Vector2(380, 214)
	parent.add_child(art)
	return art

func show_menu() -> void:
	working = false
	clear_children(page)
	heading()
	var title_card := PanelContainer.new()
	title_card.custom_minimum_size.y = 64
	title_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	title_card.add_theme_stylebox_override("panel", card_style(Color("dbe4e4"), BLUE))
	page.add_child(title_card)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 0)
	title_card.add_child(title_row)
	var title := bold_label_into(title_row, "SMELLS PHISHY.", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(row)
	var art_panel := PanelContainer.new()
	art_panel.custom_minimum_size = Vector2(720, 500)
	art_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art_panel.add_theme_stylebox_override("panel", card_style(Color("132536"), BLUE))
	row.add_child(art_panel)
	var art := office_into(art_panel)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var access_panel := PanelContainer.new()
	access_panel.custom_minimum_size.x = 430
	access_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	access_panel.add_theme_stylebox_override("panel", card_style(LIGHT_PAPER, BLUE))
	row.add_child(access_panel)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 12)
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	access_panel.add_child(menu)
	var access_bar := PanelContainer.new()
	access_bar.add_theme_stylebox_override("panel", card_style(BLUE, INK))
	menu.add_child(access_bar)
	var access := bold_label_into(access_bar, "EMPLOYEE ACCESS", 18)
	access.add_theme_color_override("font_color", Color("f3f1df"))
	var profile := card_into(menu, Color("dfe7e6"), Color("78909a"))
	rich_into(profile, "[b]LEVEL 1 / PROBATIONARY ANALYST[/b]", 17)
	var new_game := button_into(menu, "NEW GAME", show_intro)
	new_game.custom_minimum_size.y = 66
	color_action(new_game, INFO_BLUE)
	new_game.grab_focus()
	var saved := FileAccess.file_exists(SAVE_PATH)
	var resume := button_into(menu, "CONTINUE / SAVED SHIFT" if saved else "CONTINUE / DAY 01", resume_game)
	resume.disabled = not checkpoint
	resume.custom_minimum_size.y = 64
	var settings := button_into(menu, "SETTINGS", show_settings)
	settings.custom_minimum_size.y = 64
	var quit := button_into(menu, "QUIT", func(): get_tree().quit())
	quit.custom_minimum_size.y = 64
	add_creators_link(page)

func add_creators_link(parent: Node) -> void:
	var footer := HBoxContainer.new()
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(footer)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var link := LinkButton.new()
	link.text = "GAME CREATORS"
	link.tooltip_text = "View game creators"
	link.add_theme_font_size_override("font_size", 14)
	link.add_theme_color_override("font_color", BLUE)
	link.mouse_entered.connect(play_ui.bind("move"))
	link.pressed.connect(func():
		play_ui("click")
		show_creators()
	)
	footer.add_child(link)

func show_creators() -> void:
	if is_instance_valid(creators_overlay):
		return
	creators_overlay = Control.new()
	creators_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(creators_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.09, 0.13, 0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	creators_overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	creators_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(650, 520)
	panel.add_theme_stylebox_override("panel", panel_style(LIGHT_PAPER))
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", card_style(BLUE, INK))
	content.add_child(bar)
	var title := bold_label_into(bar, "GAME CREATORS", 22)
	title.add_theme_color_override("font_color", Color("f3f1df"))
	var names := label_into(content, "Amyla Hall\nConner Fields\nGabe Stewart\nJames De La Torre\nShola Ogunleye", 24)
	names.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	names.size_flags_vertical = Control.SIZE_EXPAND_FILL
	names.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button_into(content, "CLOSE", dismiss_creators).grab_focus()

func dismiss_creators() -> void:
	if is_instance_valid(creators_overlay):
		remove_child(creators_overlay)
		creators_overlay.queue_free()
		creators_overlay = null

func set_sound_percent(value: float) -> void:
	sound_volume = clampf(value / 100.0, 0.0, 1.0)
	apply_audio_settings()
	save_audio_settings()

func volume_slider(parent: Node, caption: String, value: float, action: Callable) -> HSlider:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 5)
	parent.add_child(block)
	var label_row := HBoxContainer.new()
	block.add_child(label_row)
	var title := label_into(label_row, caption, 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var amount := label_into(label_row, "%d%%" % roundi(value), 18)
	amount.custom_minimum_size.x = 72
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = value
	slider.custom_minimum_size = Vector2(760, 50)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(new_value: float):
		amount.text = "%d%%" % roundi(new_value)
		action.call(new_value)
	)
	block.add_child(slider)
	return slider

func show_settings() -> void:
	working = false
	clear_children(page)
	heading()
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 300)
	panel.add_theme_stylebox_override("panel", card_style(LIGHT_PAPER, BLUE))
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(content)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", card_style(BLUE, INK))
	content.add_child(bar)
	var title := bold_label_into(bar, "SOUND SETTINGS", 22)
	title.add_theme_color_override("font_color", Color("f3f1df"))
	volume_slider(content, "SOUND EFFECTS", sound_volume * 100.0, set_sound_percent)
	button_into(content, "PLAY TEST SOUND", play_ui.bind("good"))
	button_into(page, "< RETURN TO MAIN MENU", show_menu).grab_focus()

func show_intro() -> void:
	clear_save()
	checkpoint = false
	shift = null
	var body := document("NOTICE OF APPOINTMENT")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	var portrait := VBoxContainer.new()
	portrait.custom_minimum_size.x = 460
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(portrait)
	var portrait_art := office_into(portrait, true)
	portrait_art.custom_minimum_size = Vector2(460, 290)
	portrait_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bold_label_into(portrait, "MORGAN\nSecurity supervisor", 19)
	var speech_panel := PanelContainer.new()
	speech_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speech_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	speech_panel.add_theme_stylebox_override("panel", card_style(LIGHT_PAPER, BLUE))
	row.add_child(speech_panel)
	var speech := VBoxContainer.new()
	speech.alignment = BoxContainer.ALIGNMENT_CENTER
	speech.add_theme_constant_override("separation", 12)
	speech_panel.add_child(speech)
	rich_into(speech, "[b]Welcome to Smells Phishy Inc., analyst.[/b]", 27)
	rich_into(speech, "Employees forward suspicious mail to this desk. Your job is to decide what gets through.\n\n[b]APPROVE[/b] legitimate messages. [b]QUARANTINE[/b] phishing. A missed attack puts the company at risk. A false alarm interrupts someone's work.", 22)
	rich_into(speech, "Meet today's quota and accuracy requirement. [b]Three mistakes end the shift.[/b] Read carefully. The clock is running.", 22)
	button_into(page, "ACCEPT APPOINTMENT / NEXT >", show_briefing).grab_focus()

func show_training() -> void:
	var body := document("TRAINING MEMO 01")
	var header := card_into(body, LIGHT_PAPER, BLUE)
	rich_into(header, "[b]FROM:[/b] Morgan <morgan@smellsphishy.example>\n[b]SUBJECT:[/b] Do not trust display names", 18)
	var lesson := card_into(body, Color("dce4e4"), INK)
	rich_into(lesson, "[b]THE RULE[/b]", 20)
	rich_into(lesson, "Email headers show a display name and links show friendly text. Neither proves where the message came from or where the link goes.", 18)
	var legend := card_into(body, LIGHT_PAPER, INFO_BLUE)
	rich_into(legend, "[b]INSPECTION TAGS[/b]  [color=#3d6f8e][b]S[/b][/color] sender  |  [color=#9b7620][b]L[/b][/color] link  |  [color=#74527c][b]F[/b][/color] file", 18)
	rich_into(legend, "[b]Hover a colored tag[/b] to reveal the real information. [b]Click it[/b] to keep the card open.", 16)
	var practice := card_into(body, Color("f0eddc"), INK)
	bold_label_into(practice, "PRACTICE EMAIL", 13)
	inspection_field(practice, "FROM", "IT Service Desk", "S", INFO_BLUE, "ACTUAL SENDER\nsupport@smellsphishy-help.example\n\nEXPECTED DOMAIN\nsmellsphishy.example\n\nRESULT: The domains do not match.")
	plain_email_field(practice, "SUBJECT", "Account verification required")
	inspection_field(practice, "LINK", "portal.smellsphishy.example", "L", GOLD, "ACTUAL DESTINATION\nhttps://smellsphishy-login.example/verify\n\nRESULT: The visible link and destination do not match.")
	var checklist := card_into(body, Color("dce8dc"), GREEN)
	rich_into(checklist, "[b]DECISION CHECKLIST[/b]\n1. [b]Who really sent it?[/b]\n2. [b]Where does the link really go?[/b]\n3. [b]What is the final file extension?[/b]\n4. [b]What action is being requested?[/b]", 18)
	button_into(page, "OK / CLOCK IN >", start_shift).grab_focus()

func show_inbox() -> void:
	if awaiting_feedback:
		return
	selected = -1
	clear_children(reader)
	rich_into(reader, "[b]INBOX[/b]", 28)
	bold_label_into(reader, "SELECT A MESSAGE", 16)
	var inbox_art := office_into(reader)
	inbox_art.custom_minimum_size = Vector2(500, 370)
	inbox_art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rich_into(reader, "[b]OPEN  /  INSPECT  /  DECIDE[/b]", 20)
	approve.disabled = true
	quarantine.disabled = true
	refresh_inbox()

func show_feedback(correct: bool) -> void:
	play_ui("good" if correct else "bad")
	feedback_overlay = Control.new()
	feedback_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(feedback_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.07, 0.06, 0.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	feedback_overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	feedback_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 430)
	panel.add_theme_stylebox_override("panel", panel_style(PAPER))
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var title := bold_label_into(content, "ACCEPTED | CORRECT DECISION" if correct else "CITATION | SECURITY VIOLATION", 25)
	title.add_theme_color_override("font_color", GREEN if correct else RED)
	bold_label_into(content, "DAY 01 | STRIKES %d OF 3 | CLOCK PAUSED" % shift.strikes, 14)
	var review_title := "Correct. " if correct else "Incorrect. "
	var review := card_into(content, Color("dce6cc") if correct else Color("ead0c8"), GREEN if correct else RED)
	expand_card(review, 220)
	bold_label_into(review, "WHY", 14)
	rich_into(review, "[b]" + review_title + "[/b]" + shift.emails[selected].explanation, 18)
	var ok := button_into(content, "ACKNOWLEDGE / OK", advance)
	color_action(ok, GREEN if correct else RED)
	# Keep keyboard navigation inside the notice while it blocks the desk.
	ok.focus_neighbor_top = ok.get_path()
	ok.focus_neighbor_bottom = ok.get_path()
	ok.focus_next = ok.get_path()
	ok.focus_previous = ok.get_path()
	ok.grab_focus()

func prompt_exit() -> void:
	if is_instance_valid(exit_overlay):
		return
	working = false
	exit_overlay = Control.new()
	exit_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(exit_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.07, 0.06, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	exit_overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	exit_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 360)
	panel.add_theme_stylebox_override("panel", panel_style(PAPER))
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(content)
	var title := label_into(content, "ARE YOU SURE?", 28)
	title.add_theme_color_override("font_color", RED)
	label_into(content, "Save your reviewed mail, score, strikes, and clock, then go home to the main menu?", 19)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	content.add_child(actions)
	var stay := button_into(actions, "STAY AT DESK", dismiss_exit)
	stay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var leave := button_into(actions, "SAVE & GO HOME", save_and_go_home)
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_action(leave, RED)
	stay.grab_focus()

func dismiss_exit() -> void:
	if is_instance_valid(exit_overlay):
		remove_child(exit_overlay)
		exit_overlay.queue_free()
		exit_overlay = null
	working = true

func save_and_go_home() -> void:
	save_shift()
	if is_instance_valid(exit_overlay):
		remove_child(exit_overlay)
		exit_overlay.queue_free()
		exit_overlay = null
	checkpoint = true
	show_menu()

func save_shift() -> Error:
	if shift == null:
		return ERR_UNCONFIGURED
	var config := ConfigFile.new()
	config.set_value("shift", "decisions", shift.decisions)
	config.set_value("shift", "correct", shift.correct)
	config.set_value("shift", "strikes", shift.strikes)
	config.set_value("shift", "false_positives", shift.false_positives)
	config.set_value("shift", "missed_phishing", shift.missed_phishing)
	config.set_value("shift", "elapsed", shift.elapsed)
	config.set_value("shift", "decision_seconds", shift.decision_seconds)
	return config.save(SAVE_PATH)

func load_saved_shift() -> bool:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return false
	var restored = ShiftRules.new()
	if restored.load_content() != OK:
		return false
	restored.decisions = config.get_value("shift", "decisions", {})
	restored.correct = int(config.get_value("shift", "correct", 0))
	restored.strikes = int(config.get_value("shift", "strikes", 0))
	restored.false_positives = int(config.get_value("shift", "false_positives", 0))
	restored.missed_phishing = int(config.get_value("shift", "missed_phishing", 0))
	restored.elapsed = float(config.get_value("shift", "elapsed", 0.0))
	restored.decision_seconds = float(config.get_value("shift", "decision_seconds", 0.0))
	if restored.finished():
		return false
	shift = restored
	selected = -1
	awaiting_feedback = false
	return true

func resume_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		if load_saved_shift():
			start_shift()
			return
		clear_save()
	show_briefing()

func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func show_termination() -> void:
	checkpoint = false
	var body := document("[ TERMINATED ]")
	(body.get_child(0) as RichTextLabel).add_theme_color_override("default_color", RED)
	var reason := "You did not meet the required accuracy of 75%."
	if shift != null and shift.strikes >= 3:
		reason = "Three security violations were recorded during your shift."
	elif shift != null and shift.decisions.size() < shift.emails.size():
		reason = "You did not process the required eight emails before the end of the shift."
	var notice := card_into(body, Color("ead0c8"), RED)
	expand_card(notice, 390)
	rich_into(notice, "[b]Your probationary appointment has ended.[/b]", 29)
	bold_label_into(notice, reason, 24)
	rich_into(notice, "[b]Your desk access has been revoked.[/b]\n\nTake the lessons from this shift with you: [b]inspect the full sender address[/b], [b]check the actual link destination[/b], and [b]verify unusual requests independently[/b].", 22)
	button_into(page, "RETRY DAY 01", show_briefing)
	button_into(page, "BACK TO MAIN MENU", show_menu).grab_focus()

