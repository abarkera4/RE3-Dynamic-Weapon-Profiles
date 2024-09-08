local Scene = nil
local PlayerInventory = {}
local InventoryItemsToUpdate = {}
local WeaponProfile = nil
local OldInventoryCount = -1
local WeaponDataTables = {}
local CurrentInventory = nil
local PlayerSceneInitialized = false

local Weapons = {
	G19 = { Id = "0000", Name = "G19", Type = "HG"},
	G18B = { Id = "0100", Name = "G18B", Type = "HG"},
	G18 = { Id = "0200", Name = "G18", Type = "HG"},
	SAM = { Id = "0300", Name = "SAM", Type = "HG"},
	USP = { Id = "0600", Name = "USP", Type = "HG"},
	BM3 = { Id = 1000, Name = "BM3", Type = "SG"},
	CQBR = { Id = 2000, Name = "CQBR", Type = "SMG"},
	ICQBR = { Id = 2100, Name = "ICQBR", Type = "SMG"},
	DE50 = { Id = 3000, Name = "DE50", Type = "MAG"},
	RAI = { Id = 3100, Name = "RAI", Type = "HG"},
	MGL = { Id = 4100, Name = "MGL", Type = "GL"},
	--FLAME = { Id = 4200, Name = "FLAME", Type = "FLAM"},
	--SPARK = { Id = 4300, Name = "SPARK", Type = "HG"},
	--AT4 = { Id = 4400, Name = "AT4", Type = "GL"},
	--CMBT = { Id = 4500, Name = "CMBT", Type = "K"},
	--DOG = { Id = 4520, Name = "DOG", Type = "K"},
	--SURV = { Id = 4510, Name = "SURV", Type = "K"},
	--IAT4 = { Id = 4600, Name = "IAT4", Type = "GL"},
	--FRAG = { Id = 6200, Name = "FRAG", Type = "NADE"},
	--FLASH = { Id = 6300, Name = "FLASH", Type = "NADE"},
	--RAIL = { Id = 4700, Name = "RAIL", Type = "HG"},

}

local WeaponIDTypeMap = {
    ["0000"] = "HG",        -- VP70
    ["0100"] = "HG",        -- M1911
    ["0200"] = "HG",        -- BHP
    ["0300"] = "HG",        -- ARMY
    ["0600"] = "HG",        -- USP
  --  ["0700"] = "HG",        -- BROOM
   -- ["0800"] = "HGR",        -- SLS
    [1000] = "SG",        -- M870
    [2000] = "SMG",       -- MQ11
    [2100] = "SMG",       -- MP5
    [3000] = "MAG",       -- DE50
    [3100] = "HG",   -- RAI
    [4100] = "GL",         -- AT4
    -- [4500] = "K",         -- CMBT
    -- [4520] = "K",         -- DOG
   -- [451000] = "K",         -- SURV
   -- [4600] = "SMG",        -- IAT4
   -- [6200] = "NADE", -- FRAG
    -- [6300] = "NADE",        -- FLASH
 --   [4700] = "HG",        -- RAIL
}

local WeaponNameMap = {
    ['G19 Handgun']                   = "0000",  -- G19
    ['G18 Handgun (Burst Model)']     = "0100",  -- G18B
    ['G18 Handgun']                   = "0200",  -- G18
    ['Samurai Edge']                  = "0300",    -- SAM
    ['Infinite MUP Handgun']          = "0600",  -- USP
    ['M3 Shotgun']                    = 1000,  -- M870
    ['CQBR Assault Rifle']            = 2000,  -- MQ11
    ['Infinite CQBR Assault Rifle']   = 2100,  -- MP5
    ['.44 AE Lightning Hawk']         = 3000,  -- DE50
    ['RAI-DEN']                       = 3100,  -- RAI
    ['MGL Grenade Launcher']          = 4100,  -- FLAM
   -- ['Rocket Launcher']                         = 4400,  -- AT4
 --    ['Combat Knife']                  = 4500,  -- CMBT
    -- ['HOT DOGGER']                  = 4520,  -- CMBT2
 --   ['Survival Knife']              = 4510,  -- SURV
  --  ['Infinite Rocket Launcher']             = 4600,  -- IAT4
   -- ['Hand Grenade']                  = 6200,  -- FRAG
    -- ['Flash Grenade']                 = 6300,  -- FLASH
  --  ['Railgun'] = 4700,  -- RAIL
}

local function reset_values()
	PlayerInventory = {}
	OldInventoryCount = -1
	InventoryItemsToUpdate = {}
    CurrentInventory = nil
    PlayerSceneInitialized = false
end

local function set_weapon_profile(weaponProfile)
	WeaponProfile = weaponProfile

	if WeaponProfile then
	  for k, Weapon in pairs(Weapons) do
		log.info("Weapon Service: Loading profile for " .. Weapon.Name)
		local weaponStats = json.load_file("DWP\\" .. WeaponProfile .. "\\" .. Weapon.Name .. ".json")
		Weapon.Stats = weaponStats

		-- load defaults from None if not found
		if not Weapon.Stats then
		  weaponStats = json.load_file("DWP\\None\\" .. Weapon.Name .. ".json")
		  Weapon.Stats = weaponStats
		end

		if Weapon.CanEquipStock then
		  Weapon.StatsWithStock = json.load_file("DWP\\" .. WeaponProfile .. "\\" .. Weapon.Name .. "Stock.json")

		  if not Weapon.StatsWithStock then
			Weapon.StatsWithStock = weaponStats
		  end
		end
	  end
	end
  end

local function set_scene(scene)
	Scene = scene
end

local function player_in_scene()
	local game_master = Scene:call("findGameObject(System.String)", "30_GameMaster")
        if game_master == nil then
            return false
        end
		local player_manager = game_master:call("getComponent(System.Type)", sdk.typeof("offline.PlayerManager"))
        --log.info(" Player Manager: " .. tostring(player_manager))
        local player_context = player_manager:call("get_CurrentPlayerCondition")
        --log.info(" Player Context: " .. tostring(player_context))
    return player_context ~= nil
 end

 local function write_valuetype(parent_obj, offset, value)
    for i = 0, value.type:get_valuetype_size() - 1 do
      parent_obj:write_byte(offset + i, value:read_byte(i))
    end
  end

  local function apply_weapon_stats(weaponId)
	if PlayerInventory[weaponId] then
		table.insert(InventoryItemsToUpdate, weaponId)
	end
end

local function apply_all_weapon_stats()
	log.info("Weapon Service: Applying all weapon stats...")
	for k,v in pairs(PlayerInventory) do
		if not InventoryItemsToUpdate[k] then
			table.insert(InventoryItemsToUpdate, k)
            log.info("Weapon Service: Added weapon " .. tostring(k) .. " for update...")
		end
	end
end

local function update_player_inventory()
    local inventoryChanged = false
    local addedWeaponId = nil
    local updatedInventory = {}
    local updatedInventoryCount = 0

    -- find and cache cs inventory
    if CurrentInventory == nil then
        local InventoryMaster = Scene:call("findGameObject(System.String)", "50_InventoryMaster")
        if InventoryMaster then
            local InventoryManager = InventoryMaster:call("getComponent(System.Type)", sdk.typeof("offline.gamemastering.InventoryManager"))
            if InventoryManager then
                CurrentInventory = InventoryManager:call("get_CurrentInventory")
            end
        end
    end

    if CurrentInventory then
        local PlayerSlots = CurrentInventory:call("get_Slots")
        if PlayerSlots then
            local count = PlayerSlots:call("get_Count")
            if count then
                for i = 0, count - 1 do 
                    local item = PlayerSlots:call("get_Item", i)
                    if item then
                        local WeaponId = item:call("get_WeaponType")
                        local WeaponName = item:call("get_WeaponName")

                        if WeaponId and WeaponId ~= -1 then
                            if WeaponNameMap[WeaponName] then
                                WeaponId = WeaponNameMap[WeaponName]
                            end


                            if WeaponIDTypeMap[WeaponId] ~= nil then
                                updatedInventory[WeaponId] = item
                                updatedInventoryCount = updatedInventoryCount + 1

                                if PlayerInventory[WeaponId] == nil then
                                    addedWeaponId = WeaponId
                                    table.insert(InventoryItemsToUpdate, WeaponId)
                                    log.info("Weapon Service: Weapon " .. WeaponId .. " added to inventory")
                                end
                            end
                        end
                    end
                end
                inventoryChanged = updatedInventoryCount ~= OldInventoryCount

                if inventoryChanged then
                    log.info("inventory changed")
                    OldInventoryCount = updatedInventoryCount
                    PlayerInventory = updatedInventory
                end
            end
        end
    end

    return inventoryChanged, addedWeaponId
end


  local function get_weapon(weaponId)
	local Weapon = nil

	for k, v in pairs(Weapons) do
		if v.Id == weaponId then
			Weapon = v
			break
		end
	end

	return Weapon
end

local function update_gun(weaponId, weaponType, weaponStats)
    local gunUpdated = false
    local Gun_GameObject = Scene:call("findGameObject(System.String)", "wp" .. tostring(weaponId))

    if Gun_GameObject then
        log.info("found gun game object " .. tostring(weaponId))
        local Gun = Gun_GameObject:call("getComponent(System.Type)", sdk.typeof("offline.implement.Gun"))

        if Gun then
            log.info("found gun " .. tostring(weaponId))
            gunUpdated = true
            local ShellGen = Gun:call("get_ShellGenerator")
            local firebulletparam = Gun:call("get_FireBulletParam")
            local reticleparam = Gun:call("get_ReticleParam")
            local deviateparam = Gun:call("get_DeviateParam")

            if ShellGen then
                log.info("found shell generator" .. tostring(weaponId))
                local tgenerator = ShellGen:get_field("_TGeneratorUserDataBase")
                if tgenerator then
                    -- log.info("Got T Generator User Data")
                    local bulletgen = tgenerator:get_field("BulletGenerateSetting")
                    if bulletgen then
                        -- log.info("Got Bullet Generate Setting")
                        local shellprefab = bulletgen:get_field("ShellPrefabSetting")
                        if shellprefab then
                            -- log.info("Got Shell PrefabSettings")
                            local shelluserdata = shellprefab:get_field("ShellUserData")
                            if shelluserdata then
                                -- log.info("Got Shell User Data")
                                local ballisticsetting = shelluserdata:get_field("BallisticSetting")
                                local attacksetting = shelluserdata:get_field("AttackSetting")
                                if ballisticsetting then
                                    -- log.info("Got Ballistic Settings")
                                    ballisticsetting._Slur = weaponStats.Slur
                                    ballisticsetting._SlurFit = weaponStats.SlurFit
                                    ballisticsetting._HitNum = weaponStats.HitNum
                                    ballisticsetting._HitNumBonusFit = weaponStats.HitNumBonusFit
                                    ballisticsetting._HitNumBonusCritical = weaponStats.HitNumBonusCritical
                                    ballisticsetting._PerformanceValue = weaponStats.PerformanceValue
                                    ballisticsetting._Speed = weaponStats.BulletSpeed
                                    ballisticsetting._FiringRange = weaponStats.MaxRange
                                    ballisticsetting._EffectiveRange = weaponStats.EffectiveRange
                                    ballisticsetting._Gravity = weaponStats.Gravity
                                    -- log.info("Set Ballistic Settings")
                                end

                                if attacksetting then
                                    local critratio = attacksetting:get_field("CriticalRatio")
                                    if critratio then
                                        critratio._Ratio = weaponStats.CritRate
                                        -- log.info("Set Crit Rate")
                                    end
                                    local fitcritratio = attacksetting:get_field("FitCriticalRatio")
                                    if fitcritratio then
                                        fitcritratio._Ratio = weaponStats.CritRateFit
                                    end
                                    local normal = attacksetting:get_field("Normal")
                                    if normal then
                                        local basedamage = normal:get_field("Damage")
                                        local basewince = normal:get_field("Wince")
                                        local basebreak = normal:get_field("Break")

                                        if basedamage then
                                            basedamage._BaseValue = weaponStats.Power
                                        end

                                        if basewince then
                                            basewince._BaseValue = weaponStats.Wince
                                        end
                                        if basebreak then
                                            basebreak._BaseValue = weaponStats.Break
                                        end
                                        --log.info("Set Base Damage")
                                    end

                                    local normalrate = attacksetting:get_field("NormalRate")
                                    if normalrate then
                                        local damageratio = normalrate:get_field("Damage")
                                        local winceratio = normalrate:get_field("Wince")
                                        local breakratio = normalrate:get_field("Break")

                                        if damageratio then
                                            damageratio._BaseValue = weaponStats.PowerRate
                                        end

                                        if winceratio then
                                            winceratio._BaseValue = weaponStats.WinceRate
                                        end

                                        if breakratio then
                                            breakratio._BaseValue = weaponStats.BreakRate
                                        end
                                        -- log.info("Set Damage Rates")
                                    end
                                    local fitratio = attacksetting:get_field("FitRatioContainer")
                                    if fitratio then
                                        fitratio.Damage = weaponStats.FitRatePower
                                        fitratio.Wince = weaponStats.FitRateWince
                                        fitratio.Break = weaponStats.FitRateBreak
                                        -- log.info("Set Fit Damage")
                                    end
                                    local critratecontainer = attacksetting:get_field("CriticalRatioContainer")
                                    if critratecontainer then
                                        critratecontainer.Damage = weaponStats.CritRatePower
                                        critratecontainer.Wince = weaponStats.CritRateWince
                                        critratecontainer.Break = weaponStats.CritRateBreak
                                        log.info("Set Crit Damage")
                                    end

                                    -- log.info("Got Attack Setings")
                                end
                            end
                        end
                        if weaponType == "SG" then

                            local center = bulletgen:get_field("Center")
                            local around = bulletgen:get_field("Around")
                            local normal = bulletgen:get_field("Normal")
                            local fit = bulletgen:get_field("Fit")
                            --  Center Pellet Settings
                            if center then
                                -- log.info("Got Center")
                                local shelluserdata_center = center:get_field("ShellUserData")
                                if shelluserdata_center then
                                    -- log.info("Got Shell User Data for Center")
                                    local ballisticsetting_center = shelluserdata_center:get_field("BallisticSetting")
                                    local attacksetting_center = shelluserdata_center:get_field("AttackSetting")

                                    if ballisticsetting_center then
                                       -- log.info("Got Ballistic Settings for Center")
                                        ballisticsetting_center._Slur = weaponStats.SGCenterSlur
                                        ballisticsetting_center._SlurFit = weaponStats.SGCenterSlurFit
                                        ballisticsetting_center._HitNum = weaponStats.SGCenterHitNum
                                        ballisticsetting_center._HitNumBonusFit = weaponStats.SGCenterHitNumBonusFit
                                        ballisticsetting_center._HitNumBonusCritical =
                                            weaponStats.SGCenterHitNumBonusCritical
                                        ballisticsetting_center._PerformanceValue = weaponStats.SGCenterPerformanceValue
                                        ballisticsetting_center._Speed = weaponStats.SGCenterBulletSpeed
                                        ballisticsetting_center._FiringRange = weaponStats.SGCenterMaxRange
                                        ballisticsetting_center._EffectiveRange = weaponStats.SGCenterEffectiveRange
                                        ballisticsetting_center._Gravity = weaponStats.SGCenterGravity
                                        -- log.info("Set Ballistic Settings for Center")
                                    end

                                    if attacksetting_center then
                                        local critratio = attacksetting_center:get_field("CriticalRatio")
                                        if critratio then
                                            critratio._Ratio = weaponStats.SGCenterCritRate
                                           -- log.info("Set Crit Rate")
                                        end
                                        local fitcritratio = attacksetting_center:get_field("FitCriticalRatio")
                                        if fitcritratio then
                                            fitcritratio._Ratio = weaponStats.SGCenterCritRateFit
                                        end
                                        local normal = attacksetting_center:get_field("Normal")
                                        if normal then
                                            local basedamage = normal:get_field("Damage")
                                            local basewince = normal:get_field("Wince")
                                            local basebreak = normal:get_field("Break")

                                            if basedamage then
                                                basedamage._BaseValue = weaponStats.SGCenterPower
                                            end

                                            if basewince then
                                                basewince._BaseValue = weaponStats.SGCenterWince
                                            end
                                            if basebreak then
                                                basebreak._BaseValue = weaponStats.SGCenterBreak
                                            end
                                            -- log.info("Set Base Damage")
                                        end

                                        local normalrate = attacksetting_center:get_field("NormalRate")
                                        if normalrate then
                                            local damageratio = normalrate:get_field("Damage")
                                            local winceratio = normalrate:get_field("Wince")
                                            local breakratio = normalrate:get_field("Break")

                                            if damageratio then
                                                damageratio._BaseValue = weaponStats.SGCenterPowerRate
                                            end

                                            if winceratio then
                                                winceratio._BaseValue = weaponStats.SGCenterWinceRate
                                            end
                                            if breakratio then
                                                breakratio._BaseValue = weaponStats.SGCenterBreakRate
                                            end
                                            -- log.info("Set Damage Rates")
                                        end
                                        local fitratio = attacksetting_center:get_field("FitRatioContainer")
                                        if fitratio then
                                            fitratio.Damage = weaponStats.SGCenterFitDMG
                                            fitratio.Wince = weaponStats.SGCenterFitWINC
                                            fitratio.Break = weaponStats.SGCenterFitBRK
                                            -- log.info("Set Fit Damage")
                                        end
                                        local critratecontainer =
                                            attacksetting_center:get_field("CriticalRatioContainer")
                                        if critratecontainer then
                                            critratecontainer.Damage = weaponStats.SGCenterCritRatePower
                                            critratecontainer.Wince = weaponStats.SGCenterCritRateWince
                                            critratecontainer.Break = weaponStats.SGCenterCritRateBreak
                                            -- log.info("Set Crit Damage")
                                        end

                                        -- log.info("Set Attack Settings for Center")
                                    end
                                end
                            end

                            -- Around Pellet Settings
                            if around then
                                -- log.info("Got Around")
                                local shelluserdata_around = around:get_field("ShellUserData")
                                if shelluserdata_around then
                                    -- log.info("Got Shell User Data for Around")
                                    local ballisticsetting_around = shelluserdata_around:get_field("BallisticSetting")
                                    local attacksetting_around = shelluserdata_around:get_field("AttackSetting")

                                    if ballisticsetting_around then
                                        -- log.info("Got Ballistic Settings for Around")
                                        ballisticsetting_around._Slur = weaponStats.SGAroundSlur
                                        ballisticsetting_around._SlurFit = weaponStats.SGAroundSlurFit
                                        ballisticsetting_around._HitNum = weaponStats.SGAroundHitNum
                                        ballisticsetting_around._HitNumBonusFit = weaponStats.SGAroundHitNumBonusFit
                                        ballisticsetting_around._HitNumBonusCritical =
                                            weaponStats.SGAroundHitNumBonusCritical
                                        ballisticsetting_around._PerformanceValue = weaponStats.SGAroundPerformanceValue
                                        ballisticsetting_around._Speed = weaponStats.SGAroundBulletSpeed
                                        ballisticsetting_around._FiringRange = weaponStats.SGAroundMaxRange
                                        ballisticsetting_around._EffectiveRange = weaponStats.SGAroundEffectiveRange
                                        ballisticsetting_around._Gravity = weaponStats.SGAroundGravity
                                        -- log.info("Set Ballistic Settings for Around")
                                    end

                                    if attacksetting_around then
                                        local critratio = attacksetting_around:get_field("CriticalRatio")
                                        if critratio then
                                            critratio._Ratio = weaponStats.SGAroundCritRate
                                            -- log.info("Set Crit Rate")
                                        end
                                        local fitcritratio = attacksetting_around:get_field("FitCriticalRatio")
                                        if fitcritratio then
                                            fitcritratio._Ratio = weaponStats.SGAroundCritRateFit
                                        end
                                        local normal = attacksetting_around:get_field("Normal")
                                        if normal then
                                            local basedamage = normal:get_field("Damage")
                                            local basewince = normal:get_field("Wince")
                                            local basebreak = normal:get_field("Break")

                                            if basedamage then
                                                basedamage._BaseValue = weaponStats.SGAroundPower
                                            end

                                            if basewince then
                                                basewince._BaseValue = weaponStats.SGAroundWince
                                            end
                                            if basebreak then
                                                basebreak._BaseValue = weaponStats.SGAroundBreak
                                            end
                                            -- log.info("Set Base Damage")
                                        end

                                        local normalrate = attacksetting_around:get_field("NormalRate")
                                        if normalrate then
                                            local damageratio = normalrate:get_field("Damage")
                                            local winceratio = normalrate:get_field("Wince")
                                            local breakratio = normalrate:get_field("Break")

                                            if damageratio then
                                                damageratio._BaseValue = weaponStats.SGAroundPowerRate
                                            end

                                            if winceratio then
                                                winceratio._BaseValue = weaponStats.SGAroundWinceRate
                                            end
                                            if breakratio then
                                                breakratio._BaseValue = weaponStats.SGAroundBreakRate
                                            end
                                            -- log.info("Set Damage Rates")
                                        end
                                        local fitratio = attacksetting_around:get_field("FitRatioContainer")
                                        if fitratio then
                                            fitratio.Damage = weaponStats.SGAroundFitRatePower
                                            fitratio.Wince = weaponStats.SGAroundFitRateWince
                                            fitratio.Break = weaponStats.SGAroundFitRateBreak
                                            -- log.info("Set Fit Damage")
                                        end
                                        local critratecontainer =
                                            attacksetting_around:get_field("CriticalRatioContainer")
                                        if critratecontainer then
                                            critratecontainer.Damage = weaponStats.SGAroundCritRatePower
                                            critratecontainer.Wince = weaponStats.SGAroundCritRateWince
                                            critratecontainer.Break = weaponStats.SGAroundCritRateBreak
                                            -- log.info("Set Crit Damage")
                                        end
                                    end
                                    -- log.info("Set Attack Settings for Around")
                                end
                            end

                            if normal then
                                normal.AroundBulletNum = weaponStats.SGAroundBulletCount
                                normal.AroundBulletDegree = weaponStats.SGAroundBulletDegree
                                normal.AroundBulletLength = weaponStats.SGAroundBulletLength
                                -- log.info("Set Normal Parameters")
                            end

                            if fit then
                                fit.AroundBulletNum = weaponStats.SGAroundBulletCountFit
                                fit.AroundBulletDegree = weaponStats.SGAroundBulletDegreeFit
                                fit.AroundBulletLength = weaponStats.SGAroundBulletLengthFit
                                -- log.info("Set Fit Parameters")
                            end
                        end
                        if weaponType == "GL" then
                            local shellprefabnormal = bulletgen:get_field("ShellPrefabSettingNormal")
                            local shellprefabacid = bulletgen:get_field("ShellPrefabSettingAcid")
                            local shellprefabfire = bulletgen:get_field("ShellPrefabSettingFire")
                            local shellprefabmine = bulletgen:get_field("ShellPrefabSettingMine")

                            if shellprefabnormal and shellprefabacid and shellprefabfire then
                                local normalshelluserdata = shellprefabnormal:get_field("ShellUserData")
                                if normalshelluserdata then
                                    local ballisticsetting = normalshelluserdata:get_field("BallisticSetting")
                                    local attacksetting = normalshelluserdata:get_field("AttackSetting")
                                    if ballisticsetting then
                                        -- log.info("Got Ballistic Settings")
                                        ballisticsetting._Slur = weaponStats.Slur
                                        ballisticsetting._SlurFit = weaponStats.SlurFit
                                        ballisticsetting._HitNum = weaponStats.HitNum
                                        ballisticsetting._HitNumBonusFit = weaponStats.HitNumBonusFit
                                        ballisticsetting._HitNumBonusCritical = weaponStats.HitNumBonusCritical
                                        ballisticsetting._PerformanceValue = weaponStats.PerformanceValue
                                        ballisticsetting._Speed = weaponStats.BulletSpeed
                                        ballisticsetting._FiringRange = weaponStats.MaxRange
                                        ballisticsetting._EffectiveRange = weaponStats.EffectiveRange
                                        ballisticsetting._Gravity = weaponStats.Gravity
                                        -- log.info("Set Ballistic Settings")
                                    end
                                end
                            end

                            if shellprefabmine then
                                local mineshelluserdata = shellprefabmine:get_field("ShellUserData")
                                if mineshelluserdata then
                                    local ballisticsetting = mineshelluserdata:get_field("BallisticSetting")
                                    local attacksetting = mineshelluserdata:get_field("AttackSetting")
                                    if ballisticsetting then
                                        -- log.info("Got Ballistic Settings")
                                        ballisticsetting._Slur = weaponStats.Slur_MINE
                                        ballisticsetting._SlurFit = weaponStats.SlurFit_MINE
                                        ballisticsetting._HitNum = weaponStats.HitNum_MINE
                                        ballisticsetting._HitNumBonusFit = weaponStats.HitNumBonusFit_MINE
                                        ballisticsetting._HitNumBonusCritical = weaponStats.HitNumBonusCritical_MINE
                                        ballisticsetting._PerformanceValue = weaponStats.PerformanceValue_MINE
                                        ballisticsetting._Speed = weaponStats.BulletSpeed_MINE
                                        ballisticsetting._FiringRange = weaponStats.MaxRange_MINE
                                        ballisticsetting._EffectiveRange = weaponStats.EffectiveRange_MINE
                                        ballisticsetting._Gravity = weaponStats.Gravity_MINE
                                        -- log.info("Set Ballistic Settings")
                                    end
                                end

                            end

                        end

                    end

                end
            else
                gunUpdated = false
            end

            if reticleparam then
                reticleparam._AddPoint = weaponStats.HoldAddFocus
                reticleparam._MovePoint = weaponStats.MoveSubFocus
                reticleparam._ShootPoint = weaponStats.ShootSubFocus
                reticleparam._KeepPoint = weaponStats.KeepFitLimitFocus
                reticleparam._WatchPoint = weaponStats.WatchSubFocus
            end

            if firebulletparam then
                firebulletparam._FireBulletType = weaponStats.FireBulletType
            end

            if deviateparam then

                local yaw_form = deviateparam:call("get_TrainOffYawForm")

                if yaw_form then
                    yaw_form.s = weaponStats.RecoilHorizontalMin
                    yaw_form.r = weaponStats.RecoilHorizontalMax
                    write_valuetype(deviateparam, 0x60, yaw_form)
                   -- log.info("Set Yaw Form")
                end

                local pitch_form = deviateparam:call("get_TrainOffPitchForm")

                if pitch_form then

                    pitch_form.s = weaponStats.RecoilVerticalMin
                    pitch_form.r = weaponStats.RecoilVerticalMax
                    write_valuetype(deviateparam, 0x68, pitch_form)

                    --log.info("Set Pitch Form")
                end
            end

            local InventoryMaster = Scene:call("findGameObject(System.String)", "50_InventoryMaster")
            if InventoryMaster then
                local EquipmentManager = InventoryMaster:call("getComponent(System.Type)", sdk.typeof("offline.EquipmentManager"))
                if EquipmentManager then
                    local WeaponBulletData = EquipmentManager:call("get_WeaponBulletData")
                    if WeaponBulletData then
                        local LoadingPartsCombosForm = WeaponBulletData:call("get_LoadingPartsCombosForm")
                        if LoadingPartsCombosForm then
                            local Parts = LoadingPartsCombosForm[weaponStats.PartsIndex]
                            if Parts then
                                local WeaponLoadingPartsCombosForm = Parts:call("get_LoadingPartsCombosForm")
                                if WeaponLoadingPartsCombosForm then
                                    local WeaponLoadingParts = WeaponLoadingPartsCombosForm[0]
                                    if WeaponLoadingParts then
                                        WeaponLoadingParts:call("set_OverWriteNumberForm", weaponStats.InfiniteAmmo)
                                        WeaponLoadingParts:call("set_InfinityForm", weaponStats.InfiniteAmmo)
                                        WeaponLoadingParts._Number = weaponStats.Capacity
                                        WeaponLoadingParts._AlwaysReloadable = weaponStats.InfiniteReload
                                    end
                                end
                            end
                        end
                    end
                end
            end

        end
    end
    return gunUpdated
end

local function update_weapon(weaponId, weaponStats)
    local weaponType = WeaponIDTypeMap[weaponId]
      local weaponUpdated = false

     weaponUpdated = update_gun(weaponId, weaponType, weaponStats)



      return weaponUpdated
end

local function process_inventory_item_updates()
	local updateCount = #InventoryItemsToUpdate

	for i=1,updateCount do
		local weaponId = InventoryItemsToUpdate[i]

		if weaponId ~= nil then
            log.info("trying to get weapon " .. tostring(weaponId))
			local weapon = get_weapon(weaponId)

			if weapon then
				local weaponStats = nil
				log.info("Weapon Service: Processing stats for " .. weapon.Id .. ":" .. weapon.Name)


				weaponStats = weapon.Stats


				if weaponStats then
					local weaponUpdated = update_weapon(weaponId, weaponStats)

					if weaponUpdated then
						log.info("Weapon Service: Stats successfully applied for " .. weapon.Id .. " - " .. weapon.Name)
						table.remove(InventoryItemsToUpdate, i)
					end
				end
			end
		end
  end
end

local function on_frame()

    if reframework.get_game_name() ~= "re3" then
        return
    end
     --log.info(" On Frame and game is re3")

    local playerIsInScene = false

    if Scene then
        playerIsInScene = player_in_scene()
        -- log.info(" Player is in scene")

        if not playerIsInScene then
            reset_values();
        end
    end

    if playerIsInScene then
        update_player_inventory()

        if not PlayerSceneInitialized then
            apply_all_weapon_stats()
            PlayerSceneInitialized = true
        end

        process_inventory_item_updates()
    end
end

return {
	set_weapon_profile = set_weapon_profile,
	set_scene = set_scene,
	on_frame = on_frame,
	apply_weapon_stats = apply_weapon_stats,
	apply_all_weapon_stats = apply_all_weapon_stats,
	Weapons = Weapons
}
