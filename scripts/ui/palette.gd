class_name Palette
extends RefCounted
## The game's entire colour vocabulary. Everything drawn or themed pulls from
## here, so retuning the look is a single-file job.

const BG_DEEP    := Color("#10131b")
const BG         := Color("#171c27")
const PANEL      := Color("#1f2633")
const PANEL_HI   := Color("#2a3243")
const PANEL_DARK := Color("#151a24")
const BORDER     := Color("#38425a")
const BORDER_HI  := Color("#4d5b7a")

const TEXT       := Color("#e9edf6")
const TEXT_DIM   := Color("#98a3b9")
const TEXT_FAINT := Color("#6b768c")

const ACCENT     := Color("#f2b134")   ## amber - the game's signature colour
const ACCENT_DARK:= Color("#c48a1c")
const TEAL       := Color("#4fc3a1")
const PURPLE     := Color("#9b7fd4")
const SUCCESS    := Color("#5fb878")
const SUCCESS_HI := Color("#7de0a0")
const DANGER     := Color("#d9534f")
const DANGER_DARK:= Color("#8b2c28")
const WARN       := Color("#e08c3a")

const INK        := Color("#1a1f2b")   ## the outline colour for all character art
const UNIFORM    := Color("#e2761f")

const STAT_COLORS := {
	"strength": Color("#e0674f"),
	"intelligence": Color("#5aa9e6"),
	"stealth": Color("#9b7fd4"),
	"charisma": Color("#f2b134"),
	"luck": Color("#4fc3a1"),
	"speed": Color("#e58f4f"),
}


static func stat_color(stat: String) -> Color:
	return STAT_COLORS.get(stat, TEXT_DIM)


static func of(hex: String, fallback: Color = TEXT_DIM) -> Color:
	if hex.is_empty():
		return fallback
	return Color(hex)


static func darken(c: Color, amount: float) -> Color:
	return Color(c.r * (1.0 - amount), c.g * (1.0 - amount), c.b * (1.0 - amount), c.a)


static func lighten(c: Color, amount: float) -> Color:
	return Color(
		lerpf(c.r, 1.0, amount),
		lerpf(c.g, 1.0, amount),
		lerpf(c.b, 1.0, amount),
		c.a)


static func with_alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)
