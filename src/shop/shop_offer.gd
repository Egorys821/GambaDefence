class_name ShopOffer
extends RefCounted
## One item sold by the merchant. `apply` performs the purchase effect.

var title: String
var description: String
var icon: Texture2D
var cost: int
var apply: Callable
var sold := false
## MerchantRarity.Tier: border colour, and which bag token can bring it.
var rarity: int = MerchantRarity.Tier.COMMON


func _init(p_title: String, p_description: String, p_icon: Texture2D, p_cost: int, p_apply: Callable,
		p_rarity: int = MerchantRarity.Tier.COMMON) -> void:
	title = p_title
	description = p_description
	icon = p_icon
	cost = ShopCatalog.price(p_cost)
	apply = p_apply
	rarity = p_rarity
