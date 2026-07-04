class_name UIFonts

static var _font: Font


static func get_font() -> Font:
	if _font == null:
		var sys := SystemFont.new()
		sys.font_names = PackedStringArray([
			"Microsoft JhengHei UI",
			"Microsoft JhengHei",
			"Microsoft YaHei UI",
			"Microsoft YaHei",
			"PMingLiU",
			"MingLiU",
			"PingFang TC",
			"Noto Sans CJK TC",
		])
		sys.font_weight = 400
		sys.font_stretch = 100
		sys.allow_system_fallback = true
		_font = sys
	return _font


static func apply(node: Control) -> void:
	if node is Label or node is Button:
		node.add_theme_font_override("font", get_font())
