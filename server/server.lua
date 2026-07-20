local activeBackups = {}
local cooldowns = {}

-- Helper to send notifications to client
local function notify(src, text, kind)
    if GetResourceState('notify') == 'started' then
        TriggerClientEvent('notify:show', src, kind or 'info', 'Dispecerat', text)
    else
        TriggerClientEvent('chat:addMessage', src, {
            args = { '^1[Dispecerat]^7', text }
        })
    end
end

-- Command /bk <1-5>
RegisterCommand('bk', function(source, args, rawCommand)
    local src = source
    if src == 0 then
        print("Aceasta comanda poate fi rulata doar de pe client.")
        return
    end

    -- 1. Check if player is police
    if not Config.IsPlayerPolice(src) then
        notify(src, "Nu ai acces la canalul securizat al politiei.", "error")
        return
    end

    -- 2. Validate backup level
    local level = tonumber(args[1])
    if not level or level < 1 or level > 5 then
        notify(src, "Folosire: /bk [1-5]", "info")
        return
    end

    -- 3. Check Cooldown
    local currentTime = os.time()
    if cooldowns[src] and currentTime < cooldowns[src] then
        local waitTime = cooldowns[src] - currentTime
        notify(src, ("Trebuie sa astepti %d secunde inainte de a cere din nou sprijin."):format(waitTime), "error")
        return
    end

    -- Set cooldown
    cooldowns[src] = currentTime + Config.Cooldown

    -- 4. Request location coordinates and details from sender client
    TriggerClientEvent('lspd_backup:requestCoords', src, level)
end, false)

-- Event received from sender client with location details
RegisterNetEvent('lspd_backup:sendCoords', function(level, coords, streetName, zoneName)
    local src = source
    
    -- Double check if player is police
    if not Config.IsPlayerPolice(src) then return end

    local playerName = GetPlayerName(src) or ("ID " .. tostring(src))
    
    -- Store active backup using composite key (src_level) to allow multiple active backup levels
    local key = src .. "_" .. level
    activeBackups[key] = {
        level = level,
        coords = coords,
        street = streetName,
        zone = zoneName,
        name = playerName,
        id = src
    }

    -- Broadcast to all police officers on the server
    for _, playerId in ipairs(GetPlayers()) do
        local targetId = tonumber(playerId)
        if targetId and Config.IsPlayerPolice(targetId) then
            TriggerClientEvent('lspd_backup:showBackup', targetId, src, playerName, level, coords, streetName, zoneName)
        end
    end
end)

-- Command /cancelbk [1-5]
RegisterCommand('cancelbk', function(source, args, rawCommand)
    local src = source
    if src == 0 then return end

    if not Config.IsPlayerPolice(src) then
        notify(src, "Nu ai acces la canalul securizat al politiei.", "error")
        return
    end

    local levelArg = tonumber(args[1])
    
    if levelArg then
        -- Cancel specific backup level
        if levelArg < 1 or levelArg > 5 then
            notify(src, "Folosire: /cancelbk [1-5] sau simplu /cancelbk pentru a anula toate cererile tale.", "error")
            return
        end
        
        local key = src .. "_" .. levelArg
        if not activeBackups[key] then
            notify(src, ("Nu ai o solicitare activa pentru BK %d."):format(levelArg), "error")
            return
        end
        
        activeBackups[key] = nil
        
        -- Broadcast clear to all police officers
        for _, playerId in ipairs(GetPlayers()) do
            local targetId = tonumber(playerId)
            if targetId and Config.IsPlayerPolice(targetId) then
                TriggerClientEvent('lspd_backup:clearBackup', targetId, src, levelArg)
            end
        end
        
        notify(src, ("Ai anulat solicitarea de backup (BK %d)."):format(levelArg), "success")
    else
        -- Cancel all backups for this player
        local canceledCount = 0
        for l = 1, 5 do
            local key = src .. "_" .. l
            if activeBackups[key] then
                activeBackups[key] = nil
                canceledCount = canceledCount + 1
                
                -- Broadcast clear to all police officers
                for _, playerId in ipairs(GetPlayers()) do
                    local targetId = tonumber(playerId)
                    if targetId and Config.IsPlayerPolice(targetId) then
                        TriggerClientEvent('lspd_backup:clearBackup', targetId, src, l)
                    end
                end
            end
        end
        
        if canceledCount > 0 then
            notify(src, "Ai anulat toate solicitările tale de backup active.", "success")
        else
            notify(src, "Nu ai nicio solicitare de backup activă în acest moment.", "error")
        end
    end
end, false)

-- Remove active backups when player drops from server
AddEventHandler('playerDropped', function(reason)
    local src = source
    
    for l = 1, 5 do
        local key = src .. "_" .. l
        if activeBackups[key] then
            activeBackups[key] = nil
            
            -- Broadcast clear to all police officers
            for _, playerId in ipairs(GetPlayers()) do
                local targetId = tonumber(playerId)
                if targetId and Config.IsPlayerPolice(targetId) then
                    TriggerClientEvent('lspd_backup:clearBackup', targetId, src, l)
                end
            end
        end
    end
    
    if cooldowns[src] then
        cooldowns[src] = nil
    end
end)

-- Gunshot Alert Event from Client
RegisterNetEvent('lspd_backup:gunshotAlert', function(coords, streetName, zoneCode)
    local src = source
    if not Config.GunshotAlerts then return end

    -- Check if shooter is police and if we should ignore police shots
    if Config.IgnorePoliceShots and Config.IsPlayerPolice(src) then
        return
    end

    -- Broadcast to all police officers on the server
    for _, playerId in ipairs(GetPlayers()) do
        local targetId = tonumber(playerId)
        if targetId and Config.IsPlayerPolice(targetId) then
            TriggerClientEvent('lspd_backup:receiveGunshot', targetId, coords, streetName, zoneCode)
        end
    end
end)

