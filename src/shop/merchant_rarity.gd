class_name MerchantRarity
extends RefCounted
## Rarity tiers of merchant wares and the hidden "bag" the merchant draws from.
##
## Every offer slot draws one rarity token from the bag (without putting it
## back). When the bag is empty it is refilled with BAG_CONTENTS. So out of
## every 34 offers, exactly 1 is Legendary, 3 are Mythic, 10 Rare, 20 Common.
## The bag is never shown to the player.

enum Tier { COMMON, RARE, MYTHIC, LEGENDARY }

## Tokens of each tier in a full bag. Balance merchant luck here.
const BAG_CONTENTS := {
	Tier.COMMON: 20,
	Tier.RARE: 10,
	Tier.MYTHIC: 3,
	Tier.LEGENDARY: 1,
}

const NAMES := {
	Tier.COMMON: "Common",
	Tier.RARE: "Rare",
	Tier.MYTHIC: "Mythic",
	Tier.LEGENDARY: "Legendary",
}

## Card border colour.
const BORDER_COLORS := {
	Tier.COMMON: Color("#8a8a8a"),
	Tier.RARE: Color("#3a7ee0"),
	Tier.MYTHIC: Color("#d83030"),
	Tier.LEGENDARY: Color("#f8b020"),
}

## Text colour (titles, headers): a bit brighter than the border.
const TEXT_COLORS := {
	Tier.COMMON: Color("#c8c8c8"),
	Tier.RARE: Color("#70aaff"),
	Tier.MYTHIC: Color("#ff6060"),
	Tier.LEGENDARY: Color("#ffd040"),
}

## Card background, tinted towards the tier colour.
const BG_COLORS := {
	Tier.COMMON: Color(0.25, 0.18, 0.125, 1),
	Tier.RARE: Color(0.17, 0.17, 0.24, 1),
	Tier.MYTHIC: Color(0.27, 0.12, 0.11, 1),
	Tier.LEGENDARY: Color(0.3, 0.22, 0.08, 1),
}


static func tier_name(tier: int) -> String:
	return NAMES.get(tier, "Common")


static func text_color(tier: int) -> Color:
	return TEXT_COLORS.get(tier, TEXT_COLORS[Tier.COMMON])


## A full, shuffled bag of rarity tokens.
static func new_bag() -> Array[int]:
	var bag: Array[int] = []
	for tier: int in BAG_CONTENTS:
		for i in BAG_CONTENTS[tier]:
			bag.append(tier)
	bag.shuffle()
	return bag


## Card style (border in the tier colour) for offer cards and the preview.
static func card_style(tier: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 5.0
	style.content_margin_right = 5.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	style.bg_color = BG_COLORS.get(tier, BG_COLORS[Tier.COMMON])
	style.border_color = BORDER_COLORS.get(tier, BORDER_COLORS[Tier.COMMON])
	style.set_border_width_all(1 if tier == Tier.COMMON else 2)
	if tier == Tier.LEGENDARY:
		style.shadow_color = Color(1.0, 0.75, 0.15, 0.35)
		style.shadow_size = 3
	return style
