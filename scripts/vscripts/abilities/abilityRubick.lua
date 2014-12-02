
--隐修议员 Q1
function RubickQ1( keys )
	local caster = keys.caster
	local point = keys.target:GetOrigin()
	local caster_vec = caster:GetOrigin()
	local caster_face = caster:GetForwardVector()

	local teams = DOTA_UNIT_TARGET_TEAM_ENEMY
    local types = DOTA_UNIT_TARGET_BASIC+DOTA_UNIT_TARGET_HERO
    local flags = DOTA_UNIT_TARGET_FLAG_NOT_MAGIC_IMMUNE_ALLIES

    --获取AOE范围内的单位
    local group = FindUnitsInRadius(caster:GetTeamNumber(),point,nil,keys.radius,teams,types,flags,FIND_CLOSEST,true)

	--添加浮空效果
	for i,v in pairs(group) do
		keys.ability:ApplyDataDrivenModifier(caster,v,"modifier_rubick_q1",nil)
		keys.ability:ApplyDataDrivenModifier(caster,v,"modifier_rubick_q1_destroy",nil)
	end

	local particles = {}
	local n = 5
	for k=1,3 do
		--特效距离
		local len = k * 100
		local over = point + len * caster_face

		--创建特效
		for i=1,n do
			local vec = RotatePosition(point,QAngle(0,(360/n)*i,0),over)
			particles[i]=ParticleManager:CreateParticle("particles/units/heroes/hero_rubick/rubick_telekinesis.vpcf",PATTACH_WORLDORIGIN,caster)
			ParticleManager:SetParticleControl(particles[i],0,vec)
			ParticleManager:SetParticleControl(particles[i],1,vec)
			ParticleManager:SetParticleControl(particles[i],2,Vector(keys.dura,0,0))
			ParticleManager:ReleaseParticleIndex(particles[i])
		end
		n = n + 3
	end
end

--Q1 浮空
function rubick_q1_fly( keys )
	local target = keys.target

	local height = 0
	target.rubick_q1_fly=true
	target:SetContextThink(DoUniqueString("rubick_q1_fly"),
		function( )
			--升
			if target.rubick_q1_fly and target:IsAlive() then
				if height<keys.height then
					height = height + keys.speed

					local up = target:GetUpVector() * keys.speed
					local vec = target:GetAbsOrigin() + up
					target:SetAbsOrigin(vec)
				end

				return 0.01
			end

			--用于获取单位所在地面的Z坐标
			local min = GetGroundPosition(target:GetOrigin(),target)
			
			--降
			if target:IsAlive() then
				if height>0 then
					height = height - keys.speed
					local up = target:GetUpVector() * (-keys.speed)
					local vec = target:GetAbsOrigin() + up
					target:SetAbsOrigin(vec)

					return 0.01
				end
			end

			target:SetOrigin(min)
			return nil
		end,0)
end

--Q1 浮空消失
function RubickQ1FlyDestroy( keys )
	local target = keys.target

	target.rubick_q1_fly=false
end

--Q2
function RubickQ2( keys )
	local caster = keys.caster
	local target = keys.target

	--用于存储受到伤害的单位
	local RubickQ2Unit = {}

	--查找已受到伤害的单位
	local RubickQ2FindUnit=function( unit )
		for i,v in pairs(RubickQ2Unit) do
			if v == unit then
				return true
			end
		end
		return false
	end

	local abilityName = "add_attack_damage"
	caster:AddAbility(abilityName)
	local ability = caster:FindAbilityByName(abilityName)
	ability:SetLevel(1)

	RubickQ2Bounce(caster, caster, target, keys.ability, 0, keys.bounce_num, RubickQ2Unit, RubickQ2FindUnit )
end

--Q2 跳跃
function RubickQ2Bounce( hurtHero, caster, target, ability, bounceNum, bounceMax, RubickQ2Unit, RubickQ2FindUnit )
	--创建特效
	local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_rubick/rubick_fade_bolt_head.vpcf",PATTACH_CUSTOMORIGIN_FOLLOW,caster)
	if caster==hurtHero then
		ParticleManager:SetParticleControlEnt(particle,0,caster,5,"attach_attack1",caster:GetOrigin(),true)
	else
		ParticleManager:SetParticleControlEnt(particle,0,caster,5,"attach_hitloc",caster:GetOrigin(),true)
	end
	ParticleManager:SetParticleControlEnt(particle,1,target,5,"attach_hitloc",target:GetOrigin(),true)
	ParticleManager:ReleaseParticleIndex(particle)

	--添加目标
	table.insert(RubickQ2Unit,target)

	--造成伤害
	local lvl = ability:GetLevel() - 1
	local increase = ability:GetLevelSpecialValueFor("increase",lvl)
	local int = ability:GetLevelSpecialValueFor("int",lvl)
	local RubickQ2DamageMultiple = hurtHero.RubickQ2DamageMultiple or 0
	local damageTable = {attacker= hurtHero,
						victim=target,
						ability=ability,
						damage_increase=increase + RubickQ2DamageMultiple,
						damage_type=ability:GetAbilityDamageType(),
						damage_category="wisdom",
						damage_int=int}
	DamageTarget(damageTable)

	--E2将伤害值转化为生命值
	RubickE2( hurtHero, target.RubickE2Damage)

	--跳跃下一个目标
	local time = ability:GetLevelSpecialValueFor("time",lvl)
	if bounceNum<bounceMax then
		bounceNum = bounceNum + 1

		GameRules:GetGameModeEntity():SetContextThink(DoUniqueString("RubickQ2Bounce"),
			function( )
				local radius = ability:GetLevelSpecialValueFor("radius",lvl)
				local teams = DOTA_UNIT_TARGET_TEAM_ENEMY
			    local types = DOTA_UNIT_TARGET_BASIC+DOTA_UNIT_TARGET_HERO
			    local flags = DOTA_UNIT_TARGET_FLAG_NOT_MAGIC_IMMUNE_ALLIES

				local group = FindUnitsInRadius(hurtHero:GetTeamNumber(),target:GetOrigin(),nil,radius,teams,types,flags,FIND_CLOSEST,true)
				
				--选取跳跃的单位
				local unit = nil
				for i,v in pairs(group) do
					if RubickQ2FindUnit(v)==false then
						unit=v
						break
					end
				end

				if unit then
					RubickQ2Bounce(hurtHero, target, unit, ability, bounceNum, bounceMax, RubickQ2Unit, RubickQ2FindUnit)
				else
					--清空单位组
					local num = #RubickQ2Unit
					for i=1,num do
						table.remove(RubickQ2Unit,1)
					end

					--添加攻击力
					local attack_damage = ability:GetLevelSpecialValueFor("attack_damage",lvl)

					--获取buff持续时间
					local dura = ability:GetLevelSpecialValueFor("duration",lvl)

					--攻击力技能
					local attackAbility = hurtHero:FindAbilityByName("add_attack_damage")

					--假设最高攻击力达到十万位
					local x = 100000

					--获取加成的攻击力
					local num2 = num * attack_damage

					for i=1,6 do
						--取整数
						local bit = math.floor( num2 / x )

						--添加攻击力
						if bit>0 then
							for k=1,bit do
								local modifierName = string.format("modifier_add_attack_damage_%d",i)
								attackAbility:ApplyDataDrivenModifier(hurtHero,hurtHero,modifierName,{duration=dura})
							end
						end

						num2 = num2 % x
						x = x / 10
					end
				end

				return nil
			end,time)
	else
		--清空单位组
		local num = #RubickQ2Unit
		for i=1,num do
			table.remove(RubickQ2Unit,1)
		end

		--添加攻击力
		local attack_damage = ability:GetLevelSpecialValueFor("attack_damage",lvl)

		--获取buff持续时间
		local dura = ability:GetLevelSpecialValueFor("duration",lvl)

		--攻击力技能
		local attackAbility = hurtHero:FindAbilityByName("add_attack_damage")

		--假设最高攻击力达到十万位
		local x = 100000

		--获取加成的攻击力
		local num2 = num * attack_damage

		for i=1,6 do
			--取整数
			local bit = math.floor( num2 / x )

			--添加攻击力
			if bit>0 then
				for k=1,bit do
					local modifierName = string.format("modifier_add_attack_damage_%d",i)
					attackAbility:ApplyDataDrivenModifier(hurtHero,hurtHero,modifierName,{duration=dura})
				end
			end

			num2 = num2 % x
			x = x / 10
		end
	end
end

--Q3
function RubickQ3( keys )
	local caster = keys.caster
	local target = keys.target

	target.RubickQ3Hero=caster
	target.RubickQ3DamageType=keys.ability:GetAbilityDamageType()
	target.RubickQ3DamagePercent=(keys.damage_percent/100)
	target.RubickQ3_HealthDeficit=target:GetHealthDeficit()
	keys.ability:ApplyDataDrivenModifier(target,target,"modifier_rubick_q3_take_damage",nil)

	GameRules:GetGameModeEntity():SetContextThink(DoUniqueString("RubickQ3"),
		function( )
			if IsValidEntity(target) then
				if target:IsAlive() then
					if target:HasModifier("modifier_rubick_q3_take_damage") then
						target.RubickQ3_HealthDeficit=target:GetHealthDeficit()
						return 0.01
					end
				end
			end
			return nil
		end,0)
end

--Q3 反弹伤害
function RubickQ3TakeDamage( keys )
	local caster = keys.caster
	local attacker = keys.attacker

	--计算受到的伤害
	local heal = caster:GetHealthDeficit()
	local lose_health =  caster.RubickQ3_HealthDeficit
	local take_damage = heal - lose_health

	caster:SetHealth(caster:GetHealth() + take_damage)

	local table = {victim=attacker,
					attacker=caster.RubickQ3Hero,
					damage=take_damage * caster.RubickQ3DamagePercent,
					damage_type=caster.RubickQ3DamageType}
	ApplyDamage(table)
end

--隐修议员 W1
function RubickW1( keys )
	local caster = keys.caster
	local point = keys.target_points[1]
	caster:Stop()

	--创建幻象
	local unitName = caster:GetUnitName()
	local unit = CreateUnitByName(unitName,caster:GetOrigin(),false,nil,nil,caster:GetTeamNumber())
	unit:SetPlayerID(caster:GetPlayerOwnerID())
	unit:SetControllableByPlayer(caster:GetPlayerOwnerID(),true)
	unit:SetForwardVector((point - caster:GetAbsOrigin()):Normalized())
	unit:AddNewModifier(caster,nil,"modifier_illusion",{duration=keys.dura})
	unit:AddNewModifier(nil,nil,"modifier_phased",{duration=0.1})
	unit:AddAbility("majia2")
	unit:AddAbility("add_health")

	--生命值
	local ability2 = unit:FindAbilityByName("add_health")
	ability2:SetLevel(1)

	--假设最高攻击力达到十万位
	local x = 100000

	--获取加成的攻击力
	local num = (caster:GetIntellect() + ItemCore:GetAttribute(caster,"wisdom")) * 8

	for i=1,6 do
		--取整数
		local bit = math.floor( num / x )

		--添加攻击力
		if bit>0 then
			for k=1,bit do
				local modifierName = string.format("modifier_add_health_%d",i)
				ability2:ApplyDataDrivenModifier(caster,unit,modifierName,nil)
			end
		end

		num = num % x
		x = x / 10
	end

	local ability = unit:FindAbilityByName("majia2")
	ability:SetLevel(1)

	caster.RubickW1_illusion=unit

	--移动
	caster:SetAbsOrigin(point)
	caster:AddNewModifier(nil,nil,"modifier_phased",{duration=0.1})

	--当幻象消失删除幻象
	GameRules:GetGameModeEntity():SetContextThink(DoUniqueString("RubickW1"),
		function( )
			if IsValidEntity(unit) then
				if unit:GetHealth() <= 1 then
					unit:RemoveModifierByName("modifier_illusion")
					caster:RemoveModifierByName("modifier_rubick_w1")

					GameRules:GetGameModeEntity():SetContextThink(DoUniqueString("RubickW1"),
						function( )
							UTIL_Remove(unit)
							return nil
						end,0.1)
					return nil
				end
			end

			return 0.1
		end,0)
end

--为友军添加伤害转移buff
function RubickW1OnCreated( keys )
	local caster = keys.caster
	local target = keys.target

	if target:HasModifier("modifier_illusion")==false then
		target.RubickW1_Hero = caster
		target.RubickW1_HealthDeficit = target:GetHealthDeficit()

		keys.ability:ApplyDataDrivenModifier(target,target,"modifier_rubick_w1_buff",nil)

		GameRules:GetGameModeEntity():SetContextThink(DoUniqueString("RubickQ3"),
			function( )
				if IsValidEntity(target) then
					if target:IsAlive() then
						if target:HasModifier("modifier_rubick_w1_buff_null") then
							target.RubickW1_HealthDeficit=target:GetHealthDeficit()
							return 0.01
						end
					end
				end
				return nil
			end,0)
	end
end

--失去伤害转移bufff
function RubickW1OnDestroy( keys )
	local target = keys.target

	if target:HasModifier("modifier_illusion")==false then
		target:RemoveModifierByName("modifier_rubick_w1_buff")
	end
end

--伤害转移
function RubickW1TakeDamage( keys )
	local caster = keys.caster

	local illusion = caster.RubickW1_Hero.RubickW1_illusion

	if IsValidEntity(illusion) then

		--计算受到的伤害
		local heal = caster:GetHealthDeficit()
		local lose_health =  caster.RubickW1_HealthDeficit
		local take_damage = heal - lose_health
		
		--增加失去的生命值
		caster:SetHealth(caster:GetHealth() + take_damage)

		--把伤害转移给幻象
		illusion:SetHealth(illusion:GetHealth() - (take_damage * (keys.incoming_damage / 100)))

		--触发大招
		local hero = caster.RubickW1_Hero
		if hero:HasModifier("modifier_rubick_r1") then
			local ability = hero:FindAbilityByName("rubick_r1")
			local lvl = ability:GetLevel() - 1
			local chance = ability:GetLevelSpecialValueFor("chance",lvl)
			local radius = ability:GetLevelSpecialValueFor("radius",lvl)

			if RollPercentage(chance) then

				local teams = DOTA_UNIT_TARGET_TEAM_ENEMY
			    local types = DOTA_UNIT_TARGET_BASIC+DOTA_UNIT_TARGET_HERO
			    local flags = DOTA_UNIT_TARGET_FLAG_NOT_MAGIC_IMMUNE_ALLIES

			    --获取AOE范围内的单位
			    local group = FindUnitsInRadius(hero:GetTeamNumber(),hero:GetOrigin(),nil,radius,teams,types,flags,FIND_CLOSEST,true)
				
				local table = {caster=hero,
								target_entities=group,
								caster_entindex=hero:entindex(),
								ability=ability}
				RubickR1( table )
			end
		end
	end
end

--W2
function RubickW2( keys )
	local caster = keys.caster
	local target = keys.target

	local ability = caster:FindAbilityByName("rubick_q2")
	local lvl = ability:GetLevel()

	if lvl > 0 then
		local bounce_num = ability:GetLevelSpecialValueFor("bounce_num",lvl)
		local table ={
			caster=caster,
			target=target,
			ability=ability,
			bounce_num=bounce_num
		}
		RubickQ2(table)
	end
end

--W3
function RubickW3( keys )
	local caster = keys.caster
	local target = keys.target

	local caster_abs = caster:GetAbsOrigin()
	local caster_face = caster:GetForwardVector()

	target:SetAbsOrigin(caster_abs + caster_face * 200)

	--获取施法者力量
	local str = caster:GetStrength()

	--获取敏捷
	local agi = caster:GetAgility()

	--获取智力
	local int = caster:GetIntellect()

	--设置攻击力
	target:SetBaseDamageMax(target:GetBaseDamageMax() + int)
	target:SetBaseDamageMin(target:GetBaseDamageMin() + int)

	--设置生命值
	target:SetMaxHealth(target:GetMaxHealth() + str * keys.heal_bonus)
	target:SetHealth(target:GetMaxHealth())

	--护甲
	target:SetPhysicalArmorBaseValue(agi)
end

--隐修议员 E1
function RubickE1( keys )
	local caster = keys.caster
	local point = keys.target_points[1]

	--创建幻象
	local unitName = caster:GetUnitName()
	local unit = CreateUnitByName(unitName,point,false,nil,nil,caster:GetTeamNumber())
	unit:SetPlayerID(caster:GetPlayerOwnerID())
	unit:SetControllableByPlayer(caster:GetPlayerOwnerID(),true)
	unit:SetForwardVector((point - caster:GetAbsOrigin()):Normalized())
	unit:AddNewModifier(caster,nil,"modifier_illusion",{duration=keys.dura})
	unit:AddNewModifier(nil,nil,"modifier_phased",nil)
	unit:AddAbility("majia")
	keys.ability:ApplyDataDrivenModifier(caster,unit,"modifier_rubick_e1",nil)

	local ability = unit:FindAbilityByName("majia")
	ability:SetLevel(1)

	GameRules:GetGameModeEntity():SetContextThink(DoUniqueString("RubickE1"),
		function( )
			if IsValidEntity(unit) then
				if unit:IsAlive() then
					local teams = DOTA_UNIT_TARGET_TEAM_ENEMY
				    local types = DOTA_UNIT_TARGET_BASIC+DOTA_UNIT_TARGET_HERO
				    local flags = DOTA_UNIT_TARGET_FLAG_NONE

				    --获取范围内的单位
	    			local group = FindUnitsInRadius(caster:GetTeamNumber(),point,nil,keys.radius,teams,types,flags,FIND_CLOSEST,true)

	    			--给予敌人modifier
	    			for i,v in pairs(group) do
	    				keys.ability:ApplyDataDrivenModifier(unit,v,"modifier_rubick_e1_effect",nil)
	    			end
					return keys.time
				end	
			end

			GameRules:GetGameModeEntity():SetContextThink(DoUniqueString("RubickE1"),
				function( )
					UTIL_Remove(unit)
					return nil
				end,0.1)
			return nil
		end,0)
end

--e2 伤害转化生命值
function RubickE2( caster, damage )
	local ability = caster:FindAbilityByName("rubick_e2")
	local lvl = ability:GetLevel()

	if lvl>0 then
		local chance = ability:GetLevelSpecialValueFor("heal_chance",lvl)

		if RollPercentage(chance) then
			local radius = ability:GetLevelSpecialValueFor("radius",lvl)
			local heal_percent = ability:GetLevelSpecialValueFor("heal_percent",lvl) / 100
			local teams = DOTA_UNIT_TARGET_TEAM_FRIENDLY
		    local types = DOTA_UNIT_TARGET_BASIC+DOTA_UNIT_TARGET_HERO
		    local flags = DOTA_UNIT_TARGET_FLAG_NONE

		    local group = FindUnitsInRadius(caster:GetTeamNumber(),caster:GetOrigin(),nil,radius,teams,types,flags,FIND_CLOSEST,true)

		    for i,v in pairs(group) do
		    	local heal = math.floor(damage * heal_percent)
		    	v:SetHealth(v:GetHealth() + heal)

		    	local heal_num = #tostring(heal)

		    	--创建显示数字特效
		    	local particle = ParticleManager:CreateParticle("particles/msg_fx/msg_heal.vpcf",PATTACH_OVERHEAD_FOLLOW,v)
		    	ParticleManager:SetParticleControl(particle,0,v:GetOrigin())
		    	ParticleManager:SetParticleControl(particle,1,Vector(10,heal,0))
		    	ParticleManager:SetParticleControl(particle,2,Vector(1,heal_num + 1,0))
		    	ParticleManager:SetParticleControl(particle,3,Vector(0,255,0))
		    end
		end
	end
end

--e2 Q2伤害翻倍
function RubickE2Created( keys )
	local caster = keys.caster
	caster.RubickQ2DamageMultiple=keys.multiple
end

function RubickE2Destroy( keys )
	keys.caster.RubickQ2DamageMultiple=0
end

--E3
function RubickE3( keys )
	local caster = keys.caster
	local target = keys.target

	local abilityName_1 = "add_attack_damage"
	local abilityName_2 = "add_armor"

	local ability_1 = target:FindAbilityByName(abilityName_1)
	local ability_2 = target:FindAbilityByName(abilityName_2)

	if ability_1==nil then
		target:AddAbility(abilityName_1)
		ability_1 = target:FindAbilityByName(abilityName_1)
		ability_1:SetLevel(1)
	end
	
	if ability_2==nil then
		target:AddAbility(abilityName_2)
		ability_2 = target:FindAbilityByName(abilityName_2)
		ability_2:SetLevel(1)
	end

	--获取buff持续时间
	local dura = keys.duration

	--假设最高攻击力达到十万位
	local x = 100000

	--获取加成的攻击力
	local num1 = caster:GetIntellect()

	--获取加成的护甲
	local num2 = caster:GetAgility()

	for i=1,6 do
		--取整数
		local bit1 = math.floor( num1 / x )
		local bit2 = math.floor( num2 / x )

		--添加攻击力
		if bit1>0 then
			for k=1,bit1 do
				local modifierName = string.format("modifier_add_attack_damage_%d",i)
				ability_1:ApplyDataDrivenModifier(caster,target,modifierName,{duration=dura})
			end
		end

		--添加护甲
		if bit2>0 then
			for k=1,bit2 do
				local modifierName = string.format("modifier_add_armor_%d",i)
				ability_2:ApplyDataDrivenModifier(caster,target,modifierName,{duration=dura})
			end
		end


		num1 = num1 % x
		num2 = num2 % x
		x = x / 10
	end
end

--R1
function RubickR1( keys )
	local caster = keys.caster
	local group = keys.target_entities

	for i,v in pairs(group) do
		keys.ability:ApplyDataDrivenModifier(caster,v,"modifier_rubick_r1_buff",nil)
	end
end