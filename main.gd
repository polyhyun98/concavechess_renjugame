extends Node2D

@export var board_layer: TileMapLayer  # 체스판 TileMapLayer 연결
#@export var character_scene_p1: PackedScene
#@export var character_scene_p2: PackedScene
# 미리보기용 변수 추가
@onready var preview_sprite_p1 = $Player1Preview/Preview1
@onready var preview_sprite_p2 = $Player2Preview/Preview2
@export var character_scenes_p1: Array[PackedScene]
@export var character_scenes_p2: Array[PackedScene]
@export var attack_range_tile: PackedScene 
#@export var message_label: Label 
@onready var victory_ui = $VictioryUi
@onready var victory_label = $VictioryUi/Panel/WhoWin
@onready var highlight_marker = $HighlighMarker  # 하이라이트 노드
@onready var tooltip = $UnitTooltip
@onready var anim_player = $CenterMessagePanel/AnimationPlayer
@onready var center_panel = $CenterMessagePanel
@onready var message_label = $CenterMessagePanel/MessageLabel
@onready var pause_menu = $Pause


const BOARD_SIZE = 10  # 체스판 크기
const TILE_SIZE = 32.0

# 미리보기용 다음 유닛 저장 변수 추가
var next_unit_scene_p1: PackedScene
var next_unit_scene_p2: PackedScene

var occupied_tiles = {}
var player_turn = 0
var pending_attack = false  # 공격 모드 활성화 여부
var attacker_tile = null  # 현재 공격하는 유닛의 위치
var attack_tiles = []  # 공격 가능한 타일을 저장
var can_place = true

func _ready():
	# 게임 시작 시 첫 미리보기 갱신
	await get_tree().create_timer(1.0).timeout
	
	await show_center_message("PLAYER " + str(player_turn + 1) + " TURN", 2.0)
	
	pause_menu.visible = false
	
	update_preview_unit()
	victory_ui.visible = false
	var tile_size = board_layer.tile_set.tile_size
	
	# Sprite2D일 경우 스케일 자동 조정
	if highlight_marker is Sprite2D:
		highlight_marker.scale = Vector2(
			tile_size.x / highlight_marker.texture.get_width() * 2.0,
			tile_size.y / highlight_marker.texture.get_height() * 2.0
		)

func _process(delta):
	var mouse_pos = get_global_mouse_position()
	var local_mouse_pos = board_layer.to_local(mouse_pos)
	var tile_pos = board_layer.local_to_map(local_mouse_pos)

	if is_valid_position(tile_pos):
		var world_pos = board_layer.to_global(tile_pos * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2))
		highlight_marker.global_position = world_pos
		highlight_marker.visible = true
	else:
		highlight_marker.visible = false
	
	if occupied_tiles.has(tile_pos):
		var unit_data = occupied_tiles[tile_pos]
		if unit_data and unit_data.has("unit"):
			var unit = unit_data["unit"]
			var hp = unit.health
			var atk = unit.attack_power

			tooltip.get_node("InfoLabel").text = "HP: %d | ATK: %d" % [hp, atk]
			tooltip.global_position = board_layer.to_global(tile_pos * TILE_SIZE) + Vector2(-TILE_SIZE * 2, -TILE_SIZE * 2.5)
			tooltip.visible = true
	else:
		tooltip.visible = false

func show_center_message(text: String, duration: float = 2.0):
	can_place = false
	center_panel.visible = true
	message_label.text = text
	anim_player.play("fade_message")
	
	await anim_player.animation_finished
	center_panel.visible = false
	can_place = true
	
func get_random_unit(player_turn: int) -> PackedScene:
	var scenes = character_scenes_p1 if player_turn == 0 else character_scenes_p2
	
	if scenes.size() > 0:
		var index = randi() % scenes.size()
		return scenes[index]
	else:
		return null

func show_victory(player_turn: int):
	await get_tree().create_timer(0.5).timeout  # 0.5초 대기
	
	victory_label.text = "Player " + str(player_turn + 1)
	victory_ui.visible = true
	
func check_victory(tile_pos: Vector2i) -> bool:
	var directions = [
		Vector2i(1, 0),   # 가로 →
		Vector2i(0, 1),   # 세로 ↓
		Vector2i(1, 1),   # 대각선 ↘
		Vector2i(1, -1)   # 대각선 ↗
	]

	var current_player = player_turn

	for dir in directions:
		var count = 1  # 자기 자신 포함
		
		# 한쪽 방향(+)
		var check_pos = tile_pos + dir
		var steps = 0
		while is_valid_position(check_pos) and check_same_player(check_pos, current_player):
			count += 1
			check_pos += dir
			steps += 1
			if steps > 5:
				break
		
		# 반대 방향(-)
		check_pos = tile_pos - dir
		steps = 0
		while is_valid_position(check_pos) and check_same_player(check_pos, current_player):
			count += 1
			check_pos -= dir
			steps += 1
			if steps > 5:
				break
		
		print("방향:", dir, " count:", count) # 🔥 추가
		# 5개 이상 연결되었으면 승리
		if count >= 5:
			print("승리 조건 달성: 방향", dir)
			return true
	
	return false

func check_same_player(tile_pos: Vector2i, player: int) -> bool:
	if not occupied_tiles.has(tile_pos):
		print("occupied_tiles에 없음:", tile_pos)
		return false
	var owner = occupied_tiles[tile_pos]["player"]
	print("check_same_player 타일:", tile_pos, " 소유자:", owner, " 검사할 플레이어:", player)
	return owner == player

func _input(event):
	if not can_place:
		return  # 클릭 차단
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		var local_mouse_pos = board_layer.to_local(mouse_pos)
		var tile_pos = board_layer.local_to_map(local_mouse_pos)  # 타일맵 좌표 변환
		
		if pending_attack:
			execute_attack(tile_pos)
		if is_valid_position(tile_pos) and not is_occupied(tile_pos):
			place_character(tile_pos)

func is_valid_position(tile_pos: Vector2i) -> bool:
	return tile_pos.x >= 0 and tile_pos.x < BOARD_SIZE and tile_pos.y >= 0 and tile_pos.y < BOARD_SIZE

func is_occupied(tile_pos: Vector2i) -> bool:
	return tile_pos in occupied_tiles
	
func place_character(tile_pos: Vector2i):
	if pending_attack:
		return
	var character_scene = next_unit_scene_p1 if player_turn == 0 else next_unit_scene_p2

	
	if character_scene:
		var new_character = character_scene.instantiate()
		
		# 타일 크기 (32px) 기준으로 정확한 월드 좌표 계산
		
		var tile_center_offset = Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
		var world_pos = board_layer.to_global(tile_pos * TILE_SIZE + tile_center_offset)

		# 캐릭터 배치
		new_character.global_position = world_pos
		get_node("CharacterContainer").add_child(new_character)  # 체스말 추가
		
		occupied_tiles[tile_pos] = {"unit": new_character, "player": player_turn}
		if check_victory(tile_pos):
			
			show_victory(player_turn)
			return
		else:
			print("승자가 나오지 않았음")
		check_attackable_tiles(tile_pos)
		 # 0 → 1, 1 → 0 으로 변경
		print("체스말 배치됨 - 타일 좌표:", tile_pos, "→ 월드 좌표:", new_character.global_position)
		print("플레이어", player_turn + 1, "턴으로 변경됨")
		
		if not pending_attack:
			update_preview_unit()
		

func check_attackable_tiles(tile_pos: Vector2i):
	attack_tiles.clear()
	pending_attack = false
	var enemy_turn = 1 - player_turn
	var directions = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
					  Vector2i(-1, 0), Vector2i(1, 0),
					  Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
	for direction in directions:
		var check_tile = tile_pos + direction
		if is_valid_position(check_tile) and check_tile in occupied_tiles:
			var target = occupied_tiles[check_tile]
			if target is Dictionary and "player" in target and "unit" in target:
				var target_unit = target["unit"]
				if target["player"] == enemy_turn and is_instance_valid(target_unit):
					attack_tiles.append(check_tile)

	
	if attack_tiles.size() > 0:
		pending_attack = true
		attacker_tile = tile_pos
		
		show_attack_range()
	else:
		print("공격 가능한 유닛 없음 → 턴 자동 변경")
		end_turn()

func show_attack_range():
	# 기존의 공격 범위 타일 제거
	for child in get_node("AttackRangeContainer").get_children():
		child.queue_free()

	for tile in attack_tiles:
		var attack_marker = attack_range_tile.instantiate()
		var world_pos = board_layer.to_global(tile * TILE_SIZE + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0))
		attack_marker.global_position = world_pos
		get_node("AttackRangeContainer").add_child(attack_marker)

func adjust_attacker_direction_for_attack(attacker_unit: Node2D, attacker_player: int, target_pos: Vector2):
	var attacker_pos = attacker_unit.global_position
	
	var sprite = attacker_unit.get_node("AnimatedSprite2D")
	if sprite == null:
		return
	
	var delta = target_pos - attacker_pos
	
	var current_scale = sprite.scale  # 현재 scale 저장
	if delta.x != 0:
		# X 이동이 조금이라도 있으면 방향 결정
		if attacker_player == 0:
			# 플레이어 1 (오른쪽 기본)
			if delta.x > 0:
				sprite.scale.x = abs(current_scale.x)  # 오른쪽
			else:
				sprite.scale.x = -abs(current_scale.x)  # 왼쪽
		else:
			# 플레이어 2 (왼쪽 기본)
			if delta.x < 0:
				sprite.scale.x = abs(current_scale.x)  # 왼쪽
			else:
				sprite.scale.x = -abs(current_scale.x)  # 오른쪽
	else:
		# X 이동이 없으면 (순수 위/아래 공격) → 방향 유지
		pass

func execute_attack(tile_pos: Vector2i):  # async 키워드 추가
	if tile_pos in attack_tiles:
		print("🗡️ 전투 발생! 공격 위치:", tile_pos)
		
		if tile_pos in occupied_tiles:
			print(" occupied_tiles에서 유닛 데이터 발견:", tile_pos)
		else:
			print(" occupied_tiles에 해당 타일이 없음!", tile_pos)
		
		var target_data = occupied_tiles.get(tile_pos, null)
		
		if target_data and "unit" in target_data:
			var target_unit = target_data["unit"]
			var attacker_data = occupied_tiles.get(attacker_tile, null)
			var attacker_unit = attacker_data["unit"]
			var attacker_player = attacker_data["player"]
			
			if is_instance_valid(target_unit):
				print(" 공격 대상 유닛:", target_unit)
				
				if attacker_data and attacker_data.has("unit"):
					attacker_unit = attacker_data["unit"]
				var attack_power = attacker_unit.attack_power
				
				# 공격 방향 먼저 조정
				var world_target_pos = board_layer.to_global(tile_pos * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2))
				adjust_attacker_direction_for_attack(attacker_unit, attacker_player, world_target_pos)
				
				if attacker_unit and attacker_unit.has_method("attack_power"):
					attack_power = attacker_unit.attack_power

				if attacker_unit and attacker_unit.has_method("play_attack"):
					attacker_unit.play_attack()

				if target_unit.has_method("take_damage"):
					target_unit.take_damage(attack_power)
				
				if target_unit.health <= 0:
					target_unit.die()
					
					
					if is_instance_valid(target_unit) and tile_pos in occupied_tiles:
						occupied_tiles.erase(tile_pos)
						print("🗑️ occupied_tiles에서 유닛 정보 삭제 완료")
				else:
					print(" 유닛 생존 확인: 체력 = ", target_unit.health)
				
				# 프레임을 기다린 후 삭제 확인
				await get_tree().process_frame
				if is_instance_valid(target_unit):
					print(" 유닛이 삭제되지 않음! 추가 조치 필요:", target_unit)
				else:
					print(" 유닛 정상 삭제됨:", tile_pos)
			else:
				print(" 유닛이 이미 삭제되었거나 유효하지 않음:", tile_pos)
				
			
		else:
			print(" 유닛 데이터를 찾을 수 없음!", tile_pos)

		for child in get_node("AttackRangeContainer").get_children():
			child.queue_free()

		message_label.text = " "
		pending_attack = false
		end_turn()

func end_turn():
	pending_attack = false
	attacker_tile = null
	attack_tiles.clear()
	player_turn = 1 - player_turn
	print("턴 변경됨 → 현재 턴: 플레이어", player_turn + 1)
	
	
	await show_center_message("PLAYER " + str(player_turn + 1) + " TURN", 2.0)
	message_label.text = "플레이어 " + str(player_turn + 1) + "의 턴"
	update_preview_unit()
func apply_nearest_filter(animated_sprite: AnimatedSprite2D):
	if not animated_sprite.sprite_frames:
		return
	
	var frame_names = animated_sprite.sprite_frames.get_animation_names()
	for anim_name in frame_names:
		var frame_count = animated_sprite.sprite_frames.get_frame_count(anim_name)
		for i in range(frame_count):
			var texture = animated_sprite.sprite_frames.get_frame_texture(anim_name, i)
			if texture:
				if texture is AtlasTexture:
					var atlas = texture.atlas
					if atlas and atlas.has_method("set_texture_filter"):
						atlas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				elif texture is Texture2D:
					texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

# 유닛 미리보기 갱신 함수
func update_preview_unit():
	if player_turn == 0:
		preview_sprite_p1.visible = true
		preview_sprite_p2.visible = false
		
		var scenes = character_scenes_p1
		next_unit_scene_p1 = scenes[randi() % scenes.size()]
		
		var temp_unit = next_unit_scene_p1.instantiate()
		var sprite = temp_unit.get_node("AnimatedSprite2D")
		
		
		if sprite:
			preview_sprite_p1.sprite_frames = sprite.sprite_frames
			apply_nearest_filter(preview_sprite_p1) # 필터 적용
			preview_sprite_p1.play("Idle")
		else:
			preview_sprite_p1.sprite_frames = null
		
		temp_unit.queue_free()
		
	else:
		preview_sprite_p1.visible = false
		preview_sprite_p2.visible = true
		
		var scenes = character_scenes_p2
		next_unit_scene_p2 = scenes[randi() % scenes.size()]
		
		var temp_unit = next_unit_scene_p2.instantiate()
		var sprite = temp_unit.get_node("AnimatedSprite2D")
		
		if sprite:
			
			preview_sprite_p2.sprite_frames = sprite.sprite_frames
			apply_nearest_filter(preview_sprite_p2) # 필터 적용
			preview_sprite_p2.play("Idle")
		else:
			preview_sprite_p2.sprite_frames = null
		
		temp_unit.queue_free()



func _on_new_game_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_back_to_main_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://main_menu.tscn")


func _on_resume_pressed() -> void:
	pause_menu.visible = false
	get_tree().paused = false


func _on_button_pressed() -> void:
	
	pause_menu.visible = true
	get_tree().paused = true
	
