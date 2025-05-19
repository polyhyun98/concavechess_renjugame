extends Node2D

@export var health: int = 2
@export var attack_power: int = 1

@onready var anim = $AnimatedSprite2D

func _ready():
	anim.play("Idle")
	

func take_damage(amount: int):
	if health <= 0:
		return
		
	health -= amount
	print("🩸 유닛 피해:", amount, "→ 남은 체력:", health)
	
	if health <= 0:
		die()
	else:
		play_hit()

func die():
	print("💀 유닛 사망")
	anim.play("Death")
	if anim.is_connected("animation_finished", Callable(self, "_on_death_finished")):
		anim.disconnect("animation_finished", Callable(self, "_on_death_finished"))
	anim.connect("animation_finished", Callable(self, "_on_death_finished"))

func _on_death_finished():
	if anim.animation == "Death":
		print("✅ 죽는 애니메이션 재생 완료. 유닛 삭제.")
		await get_tree().process_frame
		queue_free()  # ✅ 이제 안전하게 삭제

func _on_anim_finished():
	if anim.animation == "Death":
		queue_free()

func play_attack():
	anim.play("Attack")
	
	# ✅ 기존 연결 제거하고 다시 연결하기 (중복 연결 방지)
	if anim.is_connected("animation_finished", Callable(self, "_on_attack_finished")):
		anim.disconnect("animation_finished", Callable(self, "_on_attack_finished"))
	anim.connect("animation_finished", Callable(self, "_on_attack_finished"))
	
	print("✅ 공격 애니메이션 실행")

func _on_attack_finished():
	print("🔥 애니메이션 종료됨: ", anim.animation)
	if anim.animation == "Attack":
		await get_tree().process_frame
		anim.play("Idle")
		print("✅ 공격 애니메이션 종료 후 idle로 전환됨")

func play_hit():
	anim.play("Hit")
	if anim.is_connected("animation_finished", Callable(self, "_on_hit_finished")):
		anim.disconnect("animation_finished", Callable(self, "_on_hit_finished"))
	anim.connect("animation_finished", Callable(self, "_on_hit_finished"))
	print("✅ 피격 애니메이션 실행: 현재 애니메이션 =", anim.animation)

func _on_hit_finished():
	if anim.animation == "Hit":
		anim.play("Idle")
