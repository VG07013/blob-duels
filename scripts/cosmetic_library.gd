class_name CosmeticLibrary
extends RefCounted

const SKINS := [
	["classic_blue", "Classic Blue", "Common"], ["red", "Red", "Common"], ["green", "Green", "Common"], ["yellow", "Yellow", "Common"], ["purple", "Purple", "Common"], ["orange", "Orange", "Common"],
	["marble", "Marble", "Rare"], ["ice", "Ice", "Rare"], ["water", "Water", "Rare"], ["toxic", "Toxic", "Rare"], ["sand", "Sand", "Rare"], ["cloud", "Cloud", "Rare"],
	["lava", "Lava", "Epic"], ["galaxy", "Galaxy", "Epic"], ["crystal", "Crystal", "Epic"], ["neon", "Neon", "Epic"], ["plasma", "Plasma", "Epic"], ["cyber", "Cyber", "Epic"],
	["black_hole", "Black Hole", "Legendary"], ["aurora", "Aurora", "Legendary"], ["gold", "Gold", "Legendary"], ["rainbow_energy", "Rainbow Energy", "Legendary"], ["dark_matter", "Dark Matter", "Legendary"], ["celestial", "Celestial", "Legendary"],
]
const TRAILS := [
	["smoke", "Smoke", "Common"], ["bubble", "Bubble", "Common"], ["dust", "Dust", "Common"], ["spark", "Spark", "Common"],
	["fire", "Fire", "Rare"], ["ice_trail", "Ice", "Rare"], ["lightning", "Lightning", "Rare"], ["snow", "Snow", "Rare"], ["leaves", "Leaves", "Rare"],
	["rainbow", "Rainbow", "Epic"], ["stars", "Stars", "Epic"], ["pixels", "Pixels", "Epic"], ["sakura", "Sakura", "Epic"], ["music_notes", "Music Notes", "Epic"],
	["galaxy_trail", "Galaxy", "Legendary"], ["black_hole_trail", "Black Hole", "Legendary"], ["meteor", "Meteor", "Legendary"], ["aurora_trail", "Aurora", "Legendary"], ["void_energy", "Void Energy", "Legendary"],
]
const KILL_EFFECTS := [
	["bubble_pop", "Bubble Pop", "Common"], ["confetti_burst", "Confetti Burst", "Common"], ["slime_splash", "Slime Splash", "Common"], ["smoke_puff", "Smoke Puff", "Common"],
	["firework", "Firework", "Rare"], ["crystal_shatter", "Crystal Shatter", "Rare"], ["comic_boom", "Comic BOOM!", "Rare"], ["lightning_strike", "Lightning Strike", "Rare"],
	["pixel_explosion", "Pixel Explosion", "Epic"], ["ice_break", "Ice Break", "Epic"], ["portal_collapse", "Portal Collapse", "Epic"], ["ufo_beam", "UFO Beam", "Epic"],
	["black_hole_burst", "Black Hole", "Legendary"], ["meteor_crash", "Meteor Crash", "Legendary"], ["supernova", "Supernova", "Legendary"], ["time_collapse", "Time Collapse", "Legendary"],
]
const FACES := [
	["happy", "Happy", "Common"], ["angry", "Angry", "Common"], ["sad", "Sad", "Common"], ["sleepy", "Sleepy", "Common"], ["surprised", "Surprised", "Common"],
	["cool", "Cool", "Rare"], ["pirate", "Pirate", "Rare"], ["evil", "Evil", "Rare"], ["nerd", "Nerd", "Rare"], ["wink", "Wink", "Rare"],
	["robot", "Robot", "Epic"], ["love_eyes", "Love Eyes", "Epic"], ["fire_eyes", "Fire Eyes", "Epic"], ["frozen", "Frozen", "Epic"], ["glitch", "Glitch", "Epic"],
	["cosmic_eyes", "Cosmic Eyes", "Legendary"], ["void_face", "Void Face", "Legendary"], ["energy_mask", "Energy Mask", "Legendary"], ["divine", "Divine", "Legendary"],
]

const PRICES := {"Common": 100, "Rare": 250, "Epic": 500, "Legendary": 1000}
const TRAIL_PRICES := {"Common": 75, "Rare": 200, "Epic": 400, "Legendary": 800}
const EFFECT_PRICES := {"Common": 125, "Rare": 300, "Epic": 600, "Legendary": 1200}
const FACE_PRICES := {"Common": 50, "Rare": 125, "Epic": 250, "Legendary": 500}


static func catalog() -> Dictionary:
	return {
		"skins": _items(SKINS, PRICES, "skin"),
		"trails": _items(TRAILS, TRAIL_PRICES, "trail"),
		"kill_effects": _items(KILL_EFFECTS, EFFECT_PRICES, "kill effect"),
		"faces": _items(FACES, FACE_PRICES, "face"),
	}


static func _items(entries: Array, prices: Dictionary, kind: String) -> Array:
	var items: Array = []
	for entry_value in entries:
		var entry := entry_value as Array
		var rarity := str(entry[2])
		items.append({"id": str(entry[0]), "name": str(entry[1]), "rarity": rarity, "price": int(prices[rarity]), "description": "%s cosmetic • %s" % [rarity, kind]})
	return items


static func skin_profile(id: String, fallback: Color) -> Dictionary:
	var profiles := {
		"classic_blue": [Color("19b7ff"), Color("b7f2ff"), "jelly"], "red": [Color("ff4254"), Color("ffd0d5"), "jelly"], "green": [Color("4eea62"), Color("d6ffb3"), "jelly"], "yellow": [Color("ffd93b"), Color("fff4ad"), "jelly"], "purple": [Color("8e55f7"), Color("e6c9ff"), "jelly"], "orange": [Color("ff872f"), Color("ffe0ac"), "jelly"],
		"marble": [Color("e8ebef"), Color("727b89"), "marble"], "ice": [Color(0.55, 0.9, 1.0, 0.68), Color("d8fbff"), "ice"], "water": [Color(0.12, 0.55, 0.95, 0.7), Color("94eaff"), "water"], "toxic": [Color("8cff20"), Color("eaff78"), "toxic"], "sand": [Color("e5bd78"), Color("fff0bd"), "sand"], "cloud": [Color("f4f7ff"), Color("b9d9ff"), "cloud"],
		"lava": [Color("281217"), Color("ff641a"), "lava"], "galaxy": [Color("171043"), Color("bb7cff"), "galaxy"], "crystal": [Color(0.3, 0.9, 1.0, 0.62), Color("ffe4ff"), "crystal"], "neon": [Color("10162a"), Color("30f3ff"), "neon"], "plasma": [Color("4c147d"), Color("ff5dea"), "plasma"], "cyber": [Color("121923"), Color("27a9ff"), "cyber"],
		"black_hole": [Color("05040d"), Color("994bff"), "black_hole"], "aurora": [Color("1f397d"), Color("58ffc3"), "aurora"], "gold": [Color("e9a91d"), Color("fff3a7"), "gold"], "rainbow_energy": [Color("ff4e8c"), Color("55e6ff"), "rainbow"], "dark_matter": [Color("1a102d"), Color("a12dff"), "dark_matter"], "celestial": [Color("f7f6ff"), Color("ffd85b"), "celestial"],
	}
	var profile := profiles.get(id, [fallback, fallback.lightened(0.4), "jelly"]) as Array
	return {"primary": profile[0], "secondary": profile[1], "effect": profile[2], "rarity": _rarity_for(SKINS, id)}


static func trail_profile(id: String) -> Dictionary:
	var profiles := {"smoke": [Color("aab2bf"), "soft"], "bubble": [Color("73dfff"), "bubble"], "dust": [Color("d6ae71"), "dust"], "spark": [Color("ffe770"), "spark"], "fire": [Color("ff6c2f"), "fire"], "ice_trail": [Color("a9f4ff"), "ice"], "lightning": [Color("bfa8ff"), "lightning"], "snow": [Color("f5fcff"), "snow"], "leaves": [Color("6fcb54"), "leaves"], "rainbow": [Color("ff63d3"), "rainbow"], "stars": [Color("fff4a8"), "stars"], "pixels": [Color("4bdcff"), "pixels"], "sakura": [Color("ff9fcb"), "sakura"], "music_notes": [Color("a36cff"), "notes"], "galaxy_trail": [Color("6e53ff"), "galaxy"], "black_hole_trail": [Color("5520b7"), "void"], "meteor": [Color("ff6f32"), "meteor"], "aurora_trail": [Color("4dffd0"), "aurora"], "void_energy": [Color("a42cff"), "void"]}
	var profile := profiles.get(id, [Color("48cfff"), "soft"]) as Array
	return {"color": profile[0], "effect": profile[1], "rarity": _rarity_for(TRAILS, id)}


static func face_profile(id: String) -> Dictionary:
	var profiles := {"happy": [Color("111827"), "happy"], "angry": [Color("ff4d4d"), "angry"], "sad": [Color("51627f"), "sad"], "sleepy": [Color("7890ae"), "sleepy"], "surprised": [Color("ffffff"), "surprised"], "cool": [Color("111111"), "cool"], "pirate": [Color("20191a"), "pirate"], "evil": [Color("ff3379"), "evil"], "nerd": [Color("6c4fff"), "nerd"], "wink": [Color("ffbd5a"), "wink"], "robot": [Color("66d8ff"), "robot"], "love_eyes": [Color("ff3d78"), "love"], "fire_eyes": [Color("ff6a27"), "fire"], "frozen": [Color("b3f7ff"), "frozen"], "glitch": [Color("64ffdb"), "glitch"], "cosmic_eyes": [Color("c2a0ff"), "cosmic"], "void_face": [Color("9c4dff"), "void"], "energy_mask": [Color("3ffaff"), "energy"], "divine": [Color("ffe18a"), "divine"]}
	var profile := profiles.get(id, [Color("111827"), "happy"]) as Array
	return {"color": profile[0], "effect": profile[1], "rarity": _rarity_for(FACES, id)}


static func kill_profile(id: String) -> Dictionary:
	var colors := {"bubble_pop": Color("64dfff"), "confetti_burst": Color("ff7db4"), "slime_splash": Color("72e85b"), "smoke_puff": Color("a7b1c3"), "firework": Color("ff6a4c"), "crystal_shatter": Color("9df4ff"), "comic_boom": Color("ffd633"), "lightning_strike": Color("bfacff"), "pixel_explosion": Color("4ddeff"), "ice_break": Color("c3f7ff"), "portal_collapse": Color("a05cff"), "ufo_beam": Color("8aff8a"), "black_hole_burst": Color("8e43ff"), "meteor_crash": Color("ff7035"), "supernova": Color("fff1a1"), "time_collapse": Color("55e8ff")}
	return {"color": colors.get(id, Color("ffb52f")), "rarity": _rarity_for(KILL_EFFECTS, id)}


static func _rarity_for(entries: Array, id: String) -> String:
	for entry_value in entries:
		var entry := entry_value as Array
		if str(entry[0]) == id:
			return str(entry[2])
	return "Common"
