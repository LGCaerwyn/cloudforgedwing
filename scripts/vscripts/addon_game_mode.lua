--[[
			==天炼:addon_game_mode.lua==
			*********2014.08.10*********
			***********AMHC*************
			============================
				Authors:
				XavierCHN
				...
			============================
]]
-------------------------------------------------------------------------------------------------------------------
-- load everyhing
require('require_everything')
-------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
if CForgedGameMode == nil then
	CForgedGameMode = class({})
end
-------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
local function PrecacheSound(sound, context )
    PrecacheResource( "soundfile", sound, context)
end
-------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
local function PrecacheParticle(particle, context )
    PrecacheResource( "particle",  particle, context)
end
-------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
local function PrecacheModel(model, context )
    PrecacheResource( "model", model, context )
end
-------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
-- Create the game mode when we activate
function Activate()
    CForgedGameMode:InitGameMode()
end
-------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
function Precache( context )
	--[[
		Precache things we know we'll use.  Possible file types include (but not limited to):
			PrecacheResource( "model", "*.vmdl", context )
			PrecacheSound( "*.vsndevts", context )
			PrecacheResource( "particle", "*.vpcf", context )
			PrecacheResource( "particle_folder", "particles/folder", context )
	]]
    -- 特效文件
	PrecacheParticle( "particles/econ/items/crystal_maiden/crystal_maiden_cowl_of_ice/maiden_crystal_nova_e_cowlofice.vpcf", context )
	PrecacheParticle( "particles/items_fx/chain_lightning.vpcf", context )
    PrecacheParticle( "particles/units/heroes/hero_shadowshaman/shadowshaman_shackle.vpcf", context )
    PrecacheParticle( "particles/cf_heros/rubick/rubick_e1.vpcf", context )

    -- 音效文件
    PrecacheSound( 'soundevents/game_sounds_heroes/game_sounds_templar_assassin.vsndevts', context)
	PrecacheSound( "soundevents/game_sounds_heroes/game_sounds_beastmaster.vsndevts", context )
	PrecacheSound( "soundevents/game_sounds_heroes/game_sounds_axe.vsndevts", context )
    PrecacheSound( "soundevents/game_sounds_heroes/game_sounds_elder_titan.vsndevts", context )
    PrecacheSound( "soundevents/game_sounds_heroes/game_sounds_crystalmaiden.vsndevts", context )
    PrecacheSound( "soundevents/game_sounds_heroes/game_sounds_huskar.vsndevts", context )
    PrecacheSound( "soundevents/game_sounds_heroes/game_sounds_lich.vsndevts", context )
    PrecacheSound( "soundevents/game_sounds_heroes/game_sounds_nevermore.vsndevts", context )
    PrecacheSound( "soundevents/game_sounds_heroes/game_sounds_skywrath_mage.vsndevts", context )
    PrecacheSound( "soundevents/game_sounds_heroes/game_sounds_omniknight.vsndevts", context )
    PrecacheSound( "soundevents/game_sounds_heroes/game_sounds_jakiro.vsndevts", context )
    PrecacheSound( "soundevents/game_sounds_heroes/game_sounds_elder_titan.vsndevts", context )
    PrecacheSound( "soundevents/game_sounds_heroes/game_sounds_shadowshaman.vsndevts", context )

    -- 小兵的统一音效
    PrecacheSound( 'soundevents/game_sounds_heroes/game_sounds_undying.vsndevts', context)
    PrecacheSound( 'soundevents/game_sounds_creeps.vsndevts', context )

    PrecacheUnitByNameAsync('npc_dota_hero_invoker', function() print('precache finished') end) 
    PrecacheUnitByNameAsync('npc_dota_hero_tusk', function() print('precache finished') end) 
    PrecacheUnitByNameAsync('npc_dota_hero_earthshaker', function() print('precache finished') end) 
    PrecacheUnitByNameAsync('npc_dota_hero_sven', function() print('precache finished') end) 
    PrecacheUnitByNameAsync('npc_dota_hero_beastmaster', function() print('precache finished') end) 
    

    -- 从KV文件统一载入小怪模型
    local unit_kv = LoadKeyValues("scripts/npc/npc_units_custom.txt")
    if unit_kv then
        for unit_name,keys in pairs(unit_kv) do
            print("precacheing resource for unit"..unit_name)
            if type(keys) == "table" then
                if keys.Model then
                    print("precacheing model"..keys.Model)
                    PrecacheModel(keys.Model, context )
                end
            end
        end
    end

    -- 从KV文件统一载入物品模型
    local item_kv = LoadKeyValues("scripts/npc/npc_items_custom.txt")
    if item_kv then
        for item_name,keys in pairs(item_kv) do
            print("precacheing resource for item"..item_name)
            if type(keys) == "table" then
                if keys.Model then
                    print("precacheing model"..keys.Model)
                    PrecacheModel(keys.Model, context )
                end
            end
        end
    end
end
-------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
-- 游戏模式初始化
function CForgedGameMode:InitGameMode()
 	
 	-- 设定游戏准备时间
	GameRules:GetGameModeEntity():SetThink( "OnThink", self, "GlobalThink", 0.1 )
    GameRules:SetHeroSelectionTime(TIME_HERO_SELECTION)
	GameRules:SetPreGameTime(TIME_PRE_GAME)

    -- 是否使用自定义的英雄经验
    GameRules:SetUseCustomHeroXPValues ( true )
    
    -- 事件监听
    --ListenToGameEvent('entity_killed', Dynamic_Wrap(CForgedGameMode, 'OnEntityKilled'), self) -- 暂时禁用
    ListenToGameEvent('dota_player_gained_level', Dynamic_Wrap(CForgedGameMode, 'OnPlayerGainLevel'), self) 
    
    --监听单位重生或者出生
    ListenToGameEvent("npc_spawned", Dynamic_Wrap(CForgedGameMode, "OnNPCSpawned"), self)

    -- 注册物品事件监听
    ItemCore:RegistEvents()

    -- 注册控制台命令
    self:RegisterConsoleCommands()

    -- 自定义等级
    self._eGameMode = GameRules:GetGameModeEntity() 
    self._eGameMode:SetUseCustomHeroLevels ( true )
    self._eGameMode:SetCustomHeroMaxLevel ( CUSTOM_MAX_LEVEL )
    self._eGameMode:SetCustomXPRequiredToReachNextLevel( CUSTOM_XP_TABLE ) --  TODO
    self._eGameMode:SetCameraDistanceOverride(1600)
	
	-- 初始化刷怪器
	CFRoundThinker:InitPara()
end
-------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
function CForgedGameMode:RegisterConsoleCommands()
    Convars:RegisterConvar('cf_spawn_enemy_unit', 'true', '如果设置为false，则不刷怪', 0 ) 
end
-------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
-- 游戏主循环
function CForgedGameMode:OnThink()
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then

		CFRoundThinker:Think()
	elseif GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
		return nil
	end
    return 0.1
end
-------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
function CForgedGameMode:OnEntityKilled( keys )
end
-------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
-- 在CFSpawner调用的游戏结束，TODO，以后可以修改
function CForgedGameMode:FinishedGame()
    GameRules:SetGameWinner(DOTA_TEAM_GOODGUYS) 
    GameRules:SetSafeToLeave(true)
end
-------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
-- 事件监听
function CForgedGameMode:OnPlayerGainLevel(keys)
    print("ON PLAYER GAIN LEVEL CALLED",keys.nPlayerID,keys.level)
    tPrintTable(keys)
    local hero = EntIndexToHScript(keys.player):GetAssignedHero()
    local nLevel = hero:GetLevel()
    -- 如果等级超过45级，不给技能点
    if nLevel > 45 then
        hero:SetAbilityPoints(hero:GetAbilityPoints() - 1)
        return
    end

    if nLevel%5 ~= 0 then
        hero:SetAbilityPoints(hero:GetAbilityPoints() - 1)
    end
end
-------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
function CForgedGameMode:RegisterLivingBoss(bossUnit)
    self._boss = self._boss or {}
    table.insert(self._boss,bossUnit)
end
-------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
--玩家可选择的英雄
GameRules.HeroCanSelect={ 
    "npc_dota_hero_axe",
    "npc_dota_hero_centaur",
    "npc_dota_hero_juggernaut",
    "npc_dota_hero_sven",
    "npc_dota_hero_phantom_assassin",
    "npc_dota_hero_templar_assassin",
    "npc_dota_hero_crystal_maiden",
    "npc_dota_hero_rubick"
}
--可选择的英雄的等级1技能
GameRules.HeroLevelOneAbility={
    "learn_ability_shuchu",
    "learn_ability_roudun",
    "learn_ability_fuzhu",
    "learn_ability_kongzhi",
    "ability_null_4"
}
--检测技能
function GameRules:FindHeroLevelOneAbility( abilityName )
    for i,v in pairs(GameRules.HeroLevelOneAbility) do
        if abilityName == v then
            return true
        end
    end
    return false
end

function CForgedGameMode:OnNPCSpawned( keys )
    local unit = EntIndexToHScript(keys.entindex)

    --判断是不是可选择的英雄且第一次出生
    for i,unitName in pairs(GameRules.HeroCanSelect) do
        --是否第一次出生
        if unit.FirstSpawn==nil then
            unit.FirstSpawn=false
        end

        --判断是不是可选择的英雄
        if unit:GetUnitName() == unitName and unit.FirstSpawn == false then
            --设置技能等级
            for k=0,5 do
                local ability = unit:GetAbilityByIndex(k)
                if ability then
                    if GameRules:FindHeroLevelOneAbility(ability:GetAbilityName()) then
                        ability:SetLevel(1)
                    end
                end
            end
            unit.FirstSpawn=true
            break
        end
    end
end
-------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------

