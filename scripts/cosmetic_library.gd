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

# Store copy is authored per item so browsing communicates the fantasy before a
# player buys it. The short line is used on cards; the longer line belongs in
# the preview stage. IDs remain unchanged for save compatibility.
const ITEM_COPY := {
	"classic_blue": ["The original icon", "The signature electric-blue jelly finish: glossy, clean, and unmistakably Blob Duels."],
	"red": ["Turn up the heat", "A hot crimson jelly coat with a soft candy highlight that stays readable in every arena."],
	"green": ["Fresh from the lab", "A vivid lime finish with a bright citrus sheen made for fast, playful movement."],
	"yellow": ["Pure sunshine", "A radiant golden-yellow jelly shell that catches light like a pocket-sized sun."],
	"purple": ["Royal jelly", "A saturated violet coat with a cool lavender highlight and a confident arcade glow."],
	"orange": ["Citrus charged", "A punchy tangerine finish with a warm cream highlight built to pop at full speed."],
	"marble": ["Carved, not poured", "Pearl stone and graphite veins flow across the blob for a sculpted luxury finish."],
	"ice": ["Cold to the core", "Translucent arctic jelly with frozen highlights and crisp crystalline reflections."],
	"water": ["Ride the current", "A deep aquatic body with bright caustic highlights that roll across its surface."],
	"toxic": ["Handle with care", "Reactive neon slime glows from within, leaving no doubt that this blob is unstable."],
	"sand": ["Arena weathered", "Warm dune tones and sun-bleached highlights give this finish a tactile desert grain."],
	"cloud": ["Soft power", "A pearl-white body with a cool sky rim, light and airy without losing its silhouette."],
	"lava": ["Pressure rising", "Black volcanic glass splits with animated molten-orange seams and a pulsing hot core."],
	"galaxy": ["Carry a universe", "Deep-space indigo swirls with violet starlight for a slow-moving cosmic surface."],
	"crystal": ["Cut for victory", "A translucent cyan shell throws sharp prismatic highlights like a living gemstone."],
	"neon": ["Night mode: loud", "Dark arcade glass is traced by an electric cyan circuit line that pulses in motion."],
	"plasma": ["Barely contained", "Magenta plasma surges beneath a dark violet membrane with an energetic inner glow."],
	"cyber": ["Combat firmware", "Graphite armor, cobalt circuitry, and a hard metallic sheen create a tuned machine look."],
	"black_hole": ["Light cannot leave", "An impossibly dark core bends violet light into a slow, ominous event horizon."],
	"aurora": ["Sky in motion", "Teal and cobalt light drift across the body in a premium northern-lights shimmer."],
	"gold": ["Champion material", "Polished trophy gold, bright specular edges, and a warm inner glow reward every angle."],
	"rainbow_energy": ["Every color. All power.", "A continuously shifting spectrum wraps the blob in high-energy prismatic light."],
	"dark_matter": ["Unknown substance", "Dense violet matter pulses beneath a near-black shell with unstable luminous fractures."],
	"celestial": ["Made among stars", "Pearl starlight and sun-gold accents create a serene, legendary cosmic finish."],

	"smoke": ["Disappear in motion", "Soft graphite wisps fade behind every burst of speed for a stealthy, weightless trail."],
	"bubble": ["Pop, drift, repeat", "Glossy cyan bubbles tumble through the air and dissolve in a playful shimmer."],
	"dust": ["Kick up the arena", "Warm granular puffs sell every landing and fling with tactile ground-hugging motion."],
	"spark": ["Tiny trail, big energy", "Sharp golden sparks snap and fade quickly for a clean competitive speed accent."],
	"fire": ["Leave a hot line", "Layered orange flames stretch behind the blob with a bright ember core."],
	"ice_trail": ["Freeze the route", "Pale-blue shards and frosted motes crackle through the air before melting away."],
	"lightning": ["Movement, electrified", "Violet-white bolts zigzag behind sudden direction changes with a charged flash."],
	"snow": ["Forecast: victory", "Soft white flakes tumble at mixed speeds for a crisp winter wake."],
	"leaves": ["A wild escape", "Fresh green leaves spin and flutter behind the blob with an organic corkscrew motion."],
	"rainbow": ["Make speed colorful", "A saturated spectrum ribbon shifts hue smoothly across the full length of the trail."],
	"stars": ["Wish upon the wake", "Golden starlets twinkle at staggered sizes before winking out behind you."],
	"pixels": ["Retro at full speed", "Cyan square fragments break away in crisp 8-bit steps with zero soft edges."],
	"sakura": ["Petals in the slipstream", "Rose-pink petals tumble and rotate gently, balancing calm beauty with fast play."],
	"music_notes": ["Bring your own soundtrack", "Violet notes bounce along the movement arc like a tiny travelling beat."],
	"galaxy_trail": ["Warp-speed starlight", "Indigo nebula motes and pinprick stars stretch into a deep-space wake."],
	"black_hole_trail": ["Gravity follows", "Dark violet orbs orbit a compressed wake before collapsing into nothing."],
	"meteor": ["Re-entry velocity", "A white-hot orange core sheds long sparks and smoke like a falling meteor."],
	"aurora_trail": ["Paint the atmosphere", "Teal ribbons wave softly through the air with luminous polar highlights."],
	"void_energy": ["Tear the arena open", "Jagged purple fragments blink between positions, leaving an unstable void seam."],

	"bubble_pop": ["A clean final pop", "The defeated blob bursts into glossy bubbles with a bright expanding cyan ring."],
	"confetti_burst": ["Celebrate every knockout", "Multicolor paper shards explode outward in a joyful competitive finish."],
	"slime_splash": ["Messy in the best way", "A juicy green splash throws heavy droplets outward before they dissolve."],
	"smoke_puff": ["Now you see them…", "A dense cartoon smoke cloud expands, rolls, and clears with a quick soft fade."],
	"firework": ["End on a high note", "A rising spark detonates into a radial firework bloom with warm color variation."],
	"crystal_shatter": ["Break beautifully", "Cyan crystal shards spear outward with glassy flashes and a sharp fracture ring."],
	"comic_boom": ["Big-panel impact", "A bold yellow starburst lands with chunky comic timing and blocky debris."],
	"lightning_strike": ["Called down from above", "A vertical violet bolt hits the arena and branches through a bright shock ring."],
	"pixel_explosion": ["Game over, 8-bit style", "The blob resolves into cyan square chunks that burst in stepped retro motion."],
	"ice_break": ["Shatter the freeze", "Frost races outward before the body breaks into pale crystalline splinters."],
	"portal_collapse": ["Exit through nowhere", "A violet portal folds inward, dragging luminous fragments into its closing ring."],
	"ufo_beam": ["Abduction confirmed", "A green energy column lifts fragments upward before snapping off into darkness."],
	"black_hole_burst": ["Total gravity failure", "A dark singularity compresses the scene, then ejects a violet event-horizon wave."],
	"meteor_crash": ["Impact from orbit", "A molten core slams down with fiery streaks, rock fragments, and a heavy shock ring."],
	"supernova": ["Outshine the arena", "A white-gold stellar flash blossoms into layered rays and a huge fading halo."],
	"time_collapse": ["The last second breaks", "Cyan clock fragments freeze, reverse, and implode through concentric time rings."],

	"happy": ["Good vibes equipped", "Bright open eyes and a soft smile make the classic friendly Blob expression."],
	"angry": ["Ready to rumble", "Low brows, hot red pupils, and a tight scowl give every duel instant attitude."],
	"sad": ["Dramatically defeated", "Cool downcast eyes and a small frown turn every bounce into lovable melodrama."],
	"sleepy": ["Five more minutes", "Heavy lids and a relaxed mouth keep this blob calm even in a chaotic arena."],
	"surprised": ["Did that just happen?", "Wide eyes and a tiny round mouth sell every ricochet with perfect comic timing."],
	"cool": ["Too cool to blink", "Glossy black shades and a confident half-smile create effortless arcade swagger."],
	"pirate": ["Claim the arena", "A stitched eye patch, dark strap, and crooked grin turn the blob into a tiny captain."],
	"evil": ["Plotting something", "Hot pink narrowed eyes and a sharp grin deliver playful villain energy."],
	"nerd": ["Calculated victory", "Square violet glasses and focused pupils make every bank shot look intentional."],
	"wink": ["One eye on the win", "A crisp wink and raised smile add a mischievous beat to every close call."],
	"robot": ["Emotion protocol online", "Cyan lens eyes and a clean metal mask give the blob a precise machine identity."],
	"love_eyes": ["Head over heels", "Bright heart-shaped eyes pulse softly over an irrepressible happy expression."],
	"fire_eyes": ["Focus: maximum", "Animated ember eyes burn orange with a hot inner core and fierce brows."],
	"frozen": ["Ice-cold composure", "Frosted pupils, pale brows, and tiny ice accents lock the expression in place."],
	"glitch": ["Signal unstable", "Offset cyan eye slices stutter between positions with digital scan-line energy."],
	"cosmic_eyes": ["See beyond the map", "Violet starfield eyes orbit tiny highlights for an otherworldly gaze."],
	"void_face": ["Nothing looks back", "Near-black eyes burn with a thin purple rim and a silent, unsettling smile."],
	"energy_mask": ["Power contained", "A luminous cyan visor spans both eyes with a sharp competitive silhouette."],
	"divine": ["Judgment has arrived", "Sun-gold eyes, a radiant brow crest, and soft halo light complete a legendary face."],
}

const PRICES := {"Common": 100, "Rare": 250, "Epic": 500, "Legendary": 1000}
const TRAIL_PRICES := {"Common": 75, "Rare": 200, "Epic": 400, "Legendary": 800}
const EFFECT_PRICES := {"Common": 125, "Rare": 300, "Epic": 600, "Legendary": 1200}
const FACE_PRICES := {"Common": 50, "Rare": 125, "Epic": 250, "Legendary": 500}


static func catalog() -> Dictionary:
	return {
		"skins": _items(SKINS, PRICES, "skins"),
		"trails": _items(TRAILS, TRAIL_PRICES, "trails"),
		"kill_effects": _items(KILL_EFFECTS, EFFECT_PRICES, "kill_effects"),
		"faces": _items(FACES, FACE_PRICES, "faces"),
	}


static func _items(entries: Array, prices: Dictionary, category: String) -> Array:
	var items: Array = []
	for entry_value in entries:
		var entry := entry_value as Array
		var item_id := str(entry[0])
		var rarity := str(entry[2])
		var copy := ITEM_COPY.get(item_id, ["Made to stand out", "A carefully tuned Blob Duels collectible with a distinctive in-game finish."]) as Array
		var profile := _profile_for_category(category, item_id)
		items.append({
			"id": item_id,
			"name": str(entry[1]),
			"rarity": rarity,
			"price": int(prices[rarity]),
			"tagline": str(copy[0]),
			"description": str(copy[1]),
			"preview_mode": category.trim_suffix("s"),
			"runtime_effect": str(profile.get("effect", item_id)),
			"profile": profile.duplicate(true),
		})
	return items


static func _profile_for_category(category: String, item_id: String) -> Dictionary:
	match category:
		"skins": return skin_profile(item_id, Color("05dcff"))
		"trails": return trail_profile(item_id)
		"kill_effects": return kill_profile(item_id)
		"faces": return face_profile(item_id)
	return {"effect": item_id}


static func skin_profile(id: String, fallback: Color) -> Dictionary:
	var profiles := {
		"classic_blue": [Color("05dcff"), Color("c8f8ff"), "jelly"], "red": [Color("ff4254"), Color("ffd0d5"), "jelly"], "green": [Color("4eea62"), Color("d6ffb3"), "jelly"], "yellow": [Color("ffd93b"), Color("fff4ad"), "jelly"], "purple": [Color("8e55f7"), Color("e6c9ff"), "jelly"], "orange": [Color("ff872f"), Color("ffe0ac"), "jelly"],
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
	return {"color": colors.get(id, Color("ffb52f")), "effect": id, "rarity": _rarity_for(KILL_EFFECTS, id)}


static func _rarity_for(entries: Array, id: String) -> String:
	for entry_value in entries:
		var entry := entry_value as Array
		if str(entry[0]) == id:
			return str(entry[2])
	return "Common"
