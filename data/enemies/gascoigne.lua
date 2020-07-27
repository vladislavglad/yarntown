local enemy = ...

local souls_enemy = require"enemies/lib/souls_enemy"

local game = enemy:get_game()
local map = enemy:get_map()
local hero = map:get_hero()
local sprite
local movement
local DAMAGE = 150
local SPEED = 100
local RANGE = 140
local DEAGRO = 900
enemy.blood_echoes = 1800
enemy.defense = 95

local DISTANCE_CHECK_INTERVAL = 1000 --original value
local CHANGE_MOVEMENT_TYPE_INTERVAL = 1500 --when to change from path_finding to target
local STUCK_CHECK_INTERVAL = 500 --when to check if stuck.
local IS_ATTACKING = false
local HANDLE_STUCK_TIMER -- Timer for Gas


function enemy:on_created()
  sprite = enemy:create_sprite("enemies/" .. enemy:get_breed())
  souls_enemy:create(enemy, {
  	--set life, damage, particular noises, etc
  	initial_movement_type = enemy:get_property("initial_movement_type") or "random",
  	damage = DAMAGE,
  	life = 2031,
  	attack_range = RANGE,
  	speed = SPEED,
  deagro_threshold = DEAGRO,
  })
end

enemy:register_event("on_dying", function()
  enemy:big_death()
  sol.audio.play_sound"bell_boom"
  enemy:get_map():get_camera():shake({})
end)



function enemy:choose_attack()
  local random = math.random(1, 100)
  --Spark Uppercut
  if enemy:get_distance(hero) > 64 and not enemy.gun_recharge then
		require("enemies/lib/attacks/gun"):attack(enemy, {
      num_bullets = 5,
    })
    enemy.recovery_time = 900
    enemy.gun_recharge = true
    sol.timer.start(map, 5000, function() enemy.gun_recharge = false end)

  elseif enemy:get_distance(hero) <= 64 and random <= 30  then
    local attack = require("enemies/lib/attacks/melee_attack")
    enemy.recovery_time = 900
    attack:attack(enemy, {
      damage = 200,
      wind_up_animation = "spark_wind_up",
      wind_up_time = "500",
      attack_sprite = "enemies/weapons/gascoigne_uppercut",
      attack_animation = "upper_cut",      
    })

  --Thrust
  elseif enemy:is_orthogonal_to_hero(8) and random < 50 and enemy:get_distance(hero) < 70 then
		local attack = require("enemies/lib/attacks/melee_attack")
		attack:set_wind_up_time(900)
		enemy.recovery_time = 800
		attack:attack(enemy, {
			damage = DAMAGE+50, attack_sprite = "enemies/weapons/axe_slam"
		})

  --Melee Combo
	elseif enemy:get_distance(hero) <= 64 then
		local attack = require("enemies/lib/attacks/tracking_combo")
		attack:set_wind_up_time(600)
		enemy.recovery_time = 400
    local potential_attack_sprites = {
      [1] = {"enemies/weapons/axe_swipe", "enemies/weapons/axe_swipe",
        "enemies/weapons/axe_slam"
      },
      [2] = {"enemies/weapons/axe_swipe", "enemies/weapons/axe_slam",},
      [3] = {"enemies/weapons/axe_swipe", "enemies/weapons/axe_swipe",},
      [4] = {"enemies/weapons/axe_swipe"},
    }
    local which_attack_set = math.random(1,4)
print("Which attack set: ", which_attack_set)
    local shoot_at_end = false
    if which_attack_set > 2 then shoot_at_end = true end
		attack:attack(enemy, {
			damage = DAMAGE,
			attack_sprites = potential_attack_sprites[which_attack_set],
      attack_sounds = {
        "cleric_beast/scream_1", "cleric_beast/scream_2", "cleric_beast/scream_3",
        "cleric_beast/scream_4", "cleric_beast/scream_5"
      },
      shoot_at_end = shoot_at_end,
		})

	else
		enemy.recovery_time = 100
		enemy:choose_next_state("recover")
  end
  

  function enemy:handle_if_stuck() 

    local initial_x, initial_y, _ = enemy:get_position()
    --print("initial coordinates:" .. initial_x .. " " .. initial_y)

    local timer = sol.timer.start(enemy, STUCK_CHECK_INTERVAL, function() 
      local current_x, current_y, _ = enemy:get_position()
      --print("current coordinates: " .. current_x .. " " .. current_y)
      if (current_x == initial_x or current_y == initial_y) then
        print("Stuck! Help!")
        m = sol.movement.create("path_finding")
        m:set_speed(SPEED)
        m:start(enemy, function() end)
        print("Finding path...\n")
      else  
      end
    end)
    return timer
  end


  function enemy:choose_next_state(previous_state)
  	if enemy:get_life() < 1 then return
    elseif not enemy.agro then
  		enemy:start_default_state()
  	elseif previous_state == "agro" then
  		enemy:approach_hero()
  	elseif previous_state == "approach" then
      enemy:choose_attack()
      IS_ATTACKING = true
    elseif previous_state == "deagro" then
      enemy:return_to_idle_location()
  	elseif previous_state == "attack" then
      enemy:recover()
      IS_ATTACKING = false
  	elseif previous_state == "recover" then
      enemy:approach_hero()
      HANDLE_STUCK_TIMER:set_suspended(false) -- Resume
  	end
  end


  function enemy:approach_hero()
    sprite:set_animation"walking"
  	local m = sol.movement.create("target")
  	m:set_speed(SPEED)
    m:start(enemy, function() end)

    HANDLE_STUCK_TIMER = enemy:handle_if_stuck() --get timer instance
    
    function m:on_obstacle_reached()
      --print("Gas reached an obsticle!")
      m = sol.movement.create("path_finding")
      m:set_speed(SPEED)
      m:start(enemy, function() end)
      --print("movement type: path_finding")

      sol.timer.start(enemy, CHANGE_MOVEMENT_TYPE_INTERVAL, 
        function() 
          m = sol.movement.create("target")
          m:set_speed(SPEED)
          m:start(enemy, function() end)
          --print("movement type: target")
        end)
    end

  	sol.timer.start(enemy, DISTANCE_CHECK_INTERVAL, function()
  		--see if close enough
    local dist = enemy:get_distance(hero)
  		if dist <= (RANGE) then
        enemy:stop_movement()
        
        HANDLE_STUCK_TIMER:set_suspended(true)
        --print("timer is suspended")

  			enemy:choose_next_state("approach")
      elseif dist >= (DEAGRO) then
        --Deagro
        enemy.agro=false
        enemy:stop_movement()
        enemy:choose_next_state("deagro")
  		else
  			return true
  		end
  	end)
  end

end

