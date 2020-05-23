local enemy = ...

local souls_enemy = require"enemies/lib/souls_enemy"

local game = enemy:get_game()
local map = enemy:get_map()
local hero = map:get_hero()
local sprite
local movement
local DAMAGE = 200
enemy.blood_echoes = 158

function enemy:on_created()
  sprite = enemy:create_sprite("enemies/" .. enemy:get_breed())
  enemy:set_size(32, 32)
  souls_enemy:create(enemy, {
  	--set life, damage, particular noises, etc
  	initial_movement_type = enemy:get_property("initial_movement_type") or "random",
  	damage = DAMAGE,
  	life = 279,
  	attack_range = 56,
  	speed = 80,
  })
end




function enemy:choose_attack()
  --TODO add sweep attack, the jab is mad easy to dodge
	if enemy:is_orthogonal_to_hero(16) then
		local num_attacks = math.random(2,6)
		enemy.recovery_time = 1400
    local multiattack = require("enemies/lib/attacks/multiattack")
    multiattack:set_wind_up_time(700)
    multiattack:set_frequency(300)
    multiattack:set_tracking(true)
		multiattack:attack(enemy, DAMAGE, "enemies/weapons/brick_jab", num_attacks)
	else
		enemy.recovery_time = 500
		enemy:choose_next_state("attack")
	end

end

