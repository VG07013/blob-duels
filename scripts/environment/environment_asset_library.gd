class_name EnvironmentAssetLibrary
extends RefCounted

const MODEL_PATHS := {
	# Kenney Mini Arcade
	"arcade_machine": "res://assets/environment/models/kenney/mini_arcade/arcade-machine.glb",
	"arcade_claw": "res://assets/environment/models/kenney/mini_arcade/claw-machine.glb",
	"arcade_pinball": "res://assets/environment/models/kenney/mini_arcade/pinball.glb",
	"arcade_dance": "res://assets/environment/models/kenney/mini_arcade/dance-machine.glb",
	"arcade_air_hockey": "res://assets/environment/models/kenney/mini_arcade/air-hockey.glb",
	"arcade_basketball": "res://assets/environment/models/kenney/mini_arcade/basketball-game.glb",
	"arcade_ticket": "res://assets/environment/models/kenney/mini_arcade/ticket-machine.glb",
	"arcade_vending": "res://assets/environment/models/kenney/mini_arcade/vending-machine.glb",
	"arcade_prize_wheel": "res://assets/environment/models/kenney/mini_arcade/prize-wheel.glb",
	"arcade_prizes": "res://assets/environment/models/kenney/mini_arcade/prizes.glb",

	# Kenney City Kit (Suburban)
	"suburban_house_a": "res://assets/environment/models/kenney/suburban/building-type-a.glb",
	"suburban_house_c": "res://assets/environment/models/kenney/suburban/building-type-c.glb",
	"suburban_house_f": "res://assets/environment/models/kenney/suburban/building-type-f.glb",
	"suburban_house_k": "res://assets/environment/models/kenney/suburban/building-type-k.glb",
	"suburban_planter": "res://assets/environment/models/kenney/suburban/planter.glb",
	"suburban_tree_large": "res://assets/environment/models/kenney/suburban/tree-large.glb",
	"suburban_tree_small": "res://assets/environment/models/kenney/suburban/tree-small.glb",
	"suburban_fence": "res://assets/environment/models/kenney/suburban/fence-1x3.glb",
	"suburban_stones": "res://assets/environment/models/kenney/suburban/path-stones-messy.glb",

	# Kenney Factory Kit
	"factory_machine": "res://assets/environment/models/kenney/factory/machine.glb",
	"factory_machine_fortified": "res://assets/environment/models/kenney/factory/machine-fortified.glb",
	"factory_robot_a": "res://assets/environment/models/kenney/factory/robot-arm-a.glb",
	"factory_robot_b": "res://assets/environment/models/kenney/factory/robot-arm-b.glb",
	"factory_crane": "res://assets/environment/models/kenney/factory/crane.glb",
	"factory_crane_magnet": "res://assets/environment/models/kenney/factory/crane-magnet.glb",
	"factory_cog_a": "res://assets/environment/models/kenney/factory/cog-a.glb",
	"factory_cog_c": "res://assets/environment/models/kenney/factory/cog-c.glb",
	"factory_screen": "res://assets/environment/models/kenney/factory/screen-wide.glb",
	"factory_catwalk": "res://assets/environment/models/kenney/factory/catwalk-straight.glb",
	"factory_catwalk_stairs": "res://assets/environment/models/kenney/factory/catwalk-stairs.glb",
	"factory_piston": "res://assets/environment/models/kenney/factory/piston-round.glb",
	"factory_structure": "res://assets/environment/models/kenney/factory/structure-high.glb",
	"factory_pipe": "res://assets/environment/models/kenney/factory/pipe-large-bend.glb",

	# Kenney Space Station Kit
	"space_barrier": "res://assets/environment/models/kenney/space_station/structure-barrier.glb",
	"space_barrier_high": "res://assets/environment/models/kenney/space_station/structure-barrier-high.glb",
	"space_container": "res://assets/environment/models/kenney/space_station/container-wide.glb",
	"space_display": "res://assets/environment/models/kenney/space_station/display-wall-wide.glb",
	"space_structure": "res://assets/environment/models/kenney/space_station/structure.glb",

	# Kenney Building Kit, used as structural facade detail
	"building_wall": "res://assets/environment/models/kenney/building/wall.glb",
	"building_wall_window": "res://assets/environment/models/kenney/building/wall-window-wide-square-detailed.glb",
	"building_doorway": "res://assets/environment/models/kenney/building/wall-doorway-wide-square.glb",
	"building_plating": "res://assets/environment/models/kenney/building/plating-detailed-wide.glb",
	"building_column": "res://assets/environment/models/kenney/building/column-wide.glb",
	"building_pipe": "res://assets/environment/models/kenney/building/detail-pipe.glb",

	# Kenney Modular Dungeon and Nature Kit
	"temple_gate": "res://assets/environment/models/kenney/dungeon/gate.glb",
	"temple_gate_bars": "res://assets/environment/models/kenney/dungeon/gate-metal-bars.glb",
	"temple_room": "res://assets/environment/models/kenney/dungeon/room-wide-variation.glb",
	"temple_corridor": "res://assets/environment/models/kenney/dungeon/corridor-wide.glb",
	"temple_stairs": "res://assets/environment/models/kenney/dungeon/stairs-wide.glb",
	"temple_wall_detail": "res://assets/environment/models/kenney/dungeon/template-wall-detail-a.glb",
	"temple_floor_detail": "res://assets/environment/models/kenney/dungeon/template-floor-detail-a.glb",
	"nature_statue_column": "res://assets/environment/models/kenney/nature/statue_column.obj",
	"nature_statue_damaged": "res://assets/environment/models/kenney/nature/statue_columnDamaged.obj",
	"nature_obelisk": "res://assets/environment/models/kenney/nature/statue_obelisk.obj",
	"nature_statue_head": "res://assets/environment/models/kenney/nature/statue_head.obj",
	"nature_rock": "res://assets/environment/models/kenney/nature/rock_largeA.obj",
	"nature_pot": "res://assets/environment/models/kenney/nature/pot_large.obj",

	# Kenney Toy Car Kit
	"toy_racer": "res://assets/environment/models/kenney/toy_car/vehicle-racer.glb",
	"toy_vintage_racer": "res://assets/environment/models/kenney/toy_car/vehicle-vintage-racer.glb",
	"toy_monster_truck": "res://assets/environment/models/kenney/toy_car/vehicle-monster-truck.glb",
	"toy_speedster": "res://assets/environment/models/kenney/toy_car/vehicle-speedster.glb",
	"toy_track": "res://assets/environment/models/kenney/toy_car/track-striped-wide-straight.glb",
	"toy_track_curve": "res://assets/environment/models/kenney/toy_car/track-striped-wide-corner-large.glb",
	"toy_track_loop": "res://assets/environment/models/kenney/toy_car/track-striped-narrow-looping.glb",
	"toy_gate": "res://assets/environment/models/kenney/toy_car/gate-finish.glb",
	"toy_item_box": "res://assets/environment/models/kenney/toy_car/item-box.glb",
	"toy_coin": "res://assets/environment/models/kenney/toy_car/item-coin-gold.glb",
	"toy_cone": "res://assets/environment/models/kenney/toy_car/item-cone.glb",
	"toy_support": "res://assets/environment/models/kenney/toy_car/supports-wide.glb",

	# Kenney Furniture Kit, used in the enclosed lobby
	"lobby_bench": "res://assets/environment/models/kenney/furniture/bench.obj",
	"lobby_bookcase": "res://assets/environment/models/kenney/furniture/bookcaseOpen.obj",
	"lobby_books": "res://assets/environment/models/kenney/furniture/books.obj",
	"lobby_sofa": "res://assets/environment/models/kenney/furniture/loungeSofa.obj",
	"lobby_chair": "res://assets/environment/models/kenney/furniture/loungeChair.obj",
	"lobby_table": "res://assets/environment/models/kenney/furniture/tableCoffee.obj",
	"lobby_lamp": "res://assets/environment/models/kenney/furniture/lampRoundFloor.obj",
	"lobby_rug": "res://assets/environment/models/kenney/furniture/rugRound.obj",
	"lobby_speaker": "res://assets/environment/models/kenney/furniture/speaker.obj",
	"lobby_plant": "res://assets/environment/models/kenney/furniture/pottedPlant.obj",
	"lobby_tv": "res://assets/environment/models/kenney/furniture/televisionVintage.obj",
	"lobby_fan": "res://assets/environment/models/kenney/furniture/ceilingFan.obj",
	"lobby_coat_rack": "res://assets/environment/models/kenney/furniture/coatRackStanding.obj",
	"lobby_bear": "res://assets/environment/models/kenney/furniture/bear.obj",
}


static func instantiate_model(model_id: String) -> Node3D:
	var source_path := String(MODEL_PATHS.get(model_id, ""))
	if source_path.is_empty():
		push_error("Unknown environment model id: %s" % model_id)
		return null
	var resource := ResourceLoader.load(source_path)
	if resource == null:
		push_error("Could not load environment model: %s" % source_path)
		return null

	var root := Node3D.new()
	root.name = "Model_%s" % model_id
	root.add_to_group("environment_model")
	root.set_meta("model_id", model_id)
	root.set_meta("model_source", source_path)
	if resource is PackedScene:
		root.add_child((resource as PackedScene).instantiate())
	elif resource is Mesh:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "ImportedMesh"
		mesh_instance.mesh = resource as Mesh
		root.add_child(mesh_instance)
	else:
		push_error("Unsupported environment model resource: %s" % source_path)
		root.free()
		return null
	for mesh_node in root.find_children("*", "MeshInstance3D", true, false):
		(mesh_node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return root
