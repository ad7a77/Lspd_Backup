local blips = {}

-- GTA V Zone Name translation dictionary
local Zones = {
    ['AIRP'] = 'Los Santos International Airport',
    ['ALAMO'] = 'Alamo Sea',
    ['ALTA'] = 'Alta',
    ['ARMYB'] = 'Fort Zancudo',
    ['BANHAMC'] = 'Banham Canyon Dr',
    ['BANNING'] = 'Banning',
    ['BAYTRE'] = 'Baytree Canyon',
    ['BEACH'] = 'Vespucci Beach',
    ['BHAMCA'] = 'Banham Canyon',
    ['BRADP'] = 'Braddock Pass',
    ['BRADT'] = 'Braddock Tunnel',
    ['BURTON'] = 'Burton',
    ['CALAFB'] = 'Calafia Bridge',
    ['CANNY'] = 'Raton Canyon',
    ['CCREAK'] = 'Cassidy Creek',
    ['CHAMH'] = 'Chamberlain Hills',
    ['CHIL'] = 'Vinewood Hills',
    ['CHU'] = 'Chumash',
    ['CLINK'] = 'Cove Link',
    ['COALG'] = 'San Chianski Mountain Range',
    ['DELBE'] = 'Del Perro Beach',
    ['DELPE'] = 'Del Perro',
    ['DELSOL'] = 'La Puerta',
    ['DEUX'] = 'Grand Senora Desert',
    ['DOWNT'] = 'Downtown',
    ['DRAFT'] = 'Land Act Reservoir',
    ['ELBURR'] = 'El Burro Heights',
    ['ELSAN'] = 'El Burro Heights',
    ['ELYSIAN'] = 'Elysian Island',
    ['GALCO'] = 'Galileo Observatory',
    ['GOLF'] = 'GWC and Golfing Society',
    ['GRAPES'] = 'Grapeseed',
    ['GREATB'] = 'Great Chaparral',
    ['HARQTY'] = 'Harmony',
    ['HAWICK'] = 'Hawick',
    ['HORS'] = 'Vinewood Racetrack',
    ['HUHUM'] = 'Humane Labs and Research',
    ['JAIL'] = 'Bolingbroke Penitentiary',
    ['KOREAT'] = 'Little Seoul',
    ['LACT'] = 'Land Act Dam',
    ['LAGO'] = 'Lago Zancudo',
    ['LDAM'] = 'Land Act Reservoir',
    ['LEGSEN'] = 'Legion Square',
    ['LMESA'] = 'La Mesa',
    ['LOSPUER'] = 'La Puerta',
    ['MIRR'] = 'Mirror Park',
    ['MISTY'] = 'Mount Gordo',
    ['MOUNTB'] = 'Mount Chiliad',
    ['MTCHIL'] = 'Mount Chiliad',
    ['MTGORDO'] = 'Mount Gordo',
    ['MTJOSE'] = 'Mount Josiah',
    ['MURRI'] = 'Murrieta Heights',
    ['NCHU'] = 'North Chumash',
    ['NOOSE'] = 'N.O.O.S.E. Headquarters',
    ['OCEANA'] = 'Pacific Ocean',
    ['PALCOV'] = 'Paleto Cove',
    ['PALETO'] = 'Paleto Bay',
    ['PALFOR'] = 'Paleto Forest',
    ['PALHIGH'] = 'Paleto Heights',
    ['PALMPOW'] = 'Palmer-Taylor Power Station',
    ['PBLUFF'] = 'Pacific Bluffs',
    ['PBOX'] = 'Pillbox Hill',
    ['RANCHO'] = 'Rancho',
    ['RGLEN'] = 'Richman Glen',
    ['RICHM'] = 'Richman',
    ['ROCKF'] = 'Rockford Hills',
    ['RTRAK'] = 'Redwood Lights Track',
    ['SANAND'] = 'San Andreas',
    ['SANCH'] = 'San Chianski Mountain Range',
    ['SANDY'] = 'Sandy Shores',
    ['SKID'] = 'Mission Row',
    ['SLAB'] = 'Slab City',
    ['STAB'] = 'Stab City',
    ['TATAMO'] = 'Tataviam Mountains',
    ['TERMINA'] = 'Terminal',
    ['TEXTI'] = 'Textile City',
    ['TONGVAH'] = 'Tongva Hills',
    ['TONGVAV'] = 'Tongva Valley',
    ['VCANA'] = 'Vespucci Canals',
    ['VESPUCCI'] = 'Vespucci',
    ['VINE'] = 'Vinewood',
    ['WINDF'] = 'Ron Alternates Wind Farm',
    ['WVINE'] = 'West Vinewood',
    ['ZANCUDO'] = 'Zancudo River',
    ['ZP_ORT'] = 'Port of South Los Santos',
    ['ZQ_UAR'] = 'Davis Quartz'
}

local function getZoneLabel(zoneCode)
    return Zones[zoneCode] or zoneCode or 'Unknown Zone'
end

-- Request location details from client when they trigger /bk on server
RegisterNetEvent('lspd_backup:requestCoords', function(level)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    
    -- Get street names
    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local streetName = GetStreetNameFromHashKey(streetHash)
    if crossingHash and crossingHash ~= 0 then
        streetName = streetName .. " / " .. GetStreetNameFromHashKey(crossingHash)
    end
    
    -- Get zone name
    local zoneCode = GetNameOfZone(coords.x, coords.y, coords.z)
    local zoneName = getZoneLabel(zoneCode)

    -- Send back to server
    TriggerServerEvent('lspd_backup:sendCoords', level, coords, streetName, zoneName)
end)

-- Receive and display backup requests from other players
RegisterNetEvent('lspd_backup:showBackup', function(senderId, senderName, level, coords, streetName, zoneName)
    local backupConfig = Config.BackupLevels[level]
    if not backupConfig then return end

    -- Play sound & show notification via NUI
    SendNUIMessage({
        action = 'showBackup',
        id = senderId,
        name = senderName,
        level = level,
        levelLabel = backupConfig.name,
        urgency = backupConfig.urgency,
        title = backupConfig.label,
        colorHex = backupConfig.colorHex,
        colorRgb = backupConfig.colorRgb,
        street = streetName,
        zone = zoneName,
        displayTime = Config.DisplayTime
    })

    -- Manage map Blip & Route using level-specific key
    local blipKey = senderId .. "_" .. level
    if blips[blipKey] then
        -- Clear existing blip/route for this sender and level
        SetBlipRoute(blips[blipKey], false)
        RemoveBlip(blips[blipKey])
        blips[blipKey] = nil
    end

    -- Create new blip
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, backupConfig.blipSprite)
    SetBlipColour(blip, backupConfig.blipColor)
    SetBlipScale(blip, backupConfig.blipScale)
    SetBlipAsShortRange(blip, false) -- Visible on the main map

    -- Set blip name in map menu
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(string.format("Backup %s - %s", backupConfig.name, senderName))
    EndTextCommandSetBlipName(blip)

    -- Flash blip if urgent
    if backupConfig.flashBlip then
        SetBlipFlashes(blip, true)
        SetBlipFlashInterval(blip, 500)
    end

    -- Draw GPS route line to the location
    if backupConfig.route then
        SetBlipRoute(blip, true)
        SetBlipRouteColour(blip, backupConfig.blipColor)
    end

    -- Store blip handle
    blips[blipKey] = blip
end)

-- Remove blip and route for a player and level
RegisterNetEvent('lspd_backup:clearBackup', function(senderId, level)
    -- Remove NUI Notification Card
    SendNUIMessage({
        action = 'clearBackup',
        id = senderId,
        level = level
    })

    local blipKey = senderId .. "_" .. level
    if blips[blipKey] then
        local blip = blips[blipKey]
        SetBlipRoute(blip, false)
        RemoveBlip(blip)
        blips[blipKey] = nil
    end
end)

-- Cleanup blips on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        for senderId, blip in pairs(blips) do
            SetBlipRoute(blip, false)
            RemoveBlip(blip)
        end
        blips = {}
    end
end)

-- Gunshot Dispatch Alerts Thread
if Config.GunshotAlerts then
    CreateThread(function()
        local lastShotTime = 0
        while true do
            Wait(0) -- Must run every frame to reliably capture IsPedShooting
            local ped = PlayerPedId()
            
            if IsPedShooting(ped) then
                local now = GetGameTimer()
                if now - lastShotTime > Config.GunshotCooldown then
                    local currentWeapon = GetSelectedPedWeapon(ped)
                    
                    -- Check if weapon is not silenced and not blacklisted
                    if not IsPedCurrentWeaponSilenced(ped) and not Config.GunshotBlacklist[currentWeapon] then
                        lastShotTime = now
                        local coords = GetEntityCoords(ped)
                        
                        -- Get street names
                        local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
                        local streetName = GetStreetNameFromHashKey(streetHash)
                        if crossingHash and crossingHash ~= 0 then
                            streetName = streetName .. " / " .. GetStreetNameFromHashKey(crossingHash)
                        end
                        
                        -- Get zone code
                        local zoneCode = GetNameOfZone(coords.x, coords.y, coords.z)
                        
                        -- Trigger gunshot alert on server
                        TriggerServerEvent('lspd_backup:gunshotAlert', coords, streetName, zoneCode)
                    end
                end
            end
        end
    end)
end

-- Receive Gunshot Dispatch Alert (Police Only)
RegisterNetEvent('lspd_backup:receiveGunshot', function(coords, streetName, zoneCode)
    -- Play a frontend police warning sound
    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", false)
    
    -- Format zone label and alert message
    local zoneName = getZoneLabel(zoneCode)
    
    -- Send red alert message to chat
    TriggerEvent('chat:addMessage', {
        color = { 255, 50, 50 },
        multiline = true,
        args = { 
            "DISPECERAT 911", 
            string.format("S-au detectat focuri de arma in zona %s, %s.", streetName, zoneName)
        }
    })

    -- Create temporary gunshot radius blip on the map (red radar circle)
    local blip = AddBlipForRadius(coords.x, coords.y, coords.z, Config.GunshotBlipRadius or 120.0)
    SetBlipColour(blip, Config.GunshotBlipColor or 1)
    SetBlipAlpha(blip, 120)
    
    -- Fade out blip gradually over Config.GunshotBlipDuration seconds
    CreateThread(function()
        local duration = Config.GunshotBlipDuration or 20.0
        local steps = 20
        local delay = math.ceil((duration * 1000) / steps)
        local alpha = 120
        
        -- Wait half of duration before starting to fade out
        Wait(math.ceil(duration * 500))
        
        while alpha > 0 do
            Wait(delay / 2)
            alpha = alpha - (120 / steps)
            if alpha < 0 then alpha = 0 end
            SetBlipAlpha(blip, math.ceil(alpha))
        end
        
        RemoveBlip(blip)
    end)
end)

