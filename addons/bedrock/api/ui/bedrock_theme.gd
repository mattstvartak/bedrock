class_name BedrockTheme
extends RefCounted
## Minimal shared theme so the kit's menus look consistent out of the box. Games
## override it with their own Theme (set it on the menu or project-wide); this is
## just a sane default, not a design system.

static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	return t
