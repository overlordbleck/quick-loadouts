util.AddNetworkString( "QuickLoadouts_Request" )
util.AddNetworkString( "QuickLoadouts_State" )

local DATA_KEY = "QuickLoadouts_Weapons"
local MAX_REQUEST_BITS = 2100
local REQUEST_INTERVAL = 0.1
local PRIMARY_AMMO_RESERVE = 256
local SECONDARY_AMMO_RESERVE = 5

local function giveLoadoutAmmo( ply )
    local ammoTypes = {}
    for _, weapon in ipairs( ply:GetWeapons() ) do
        local primary = weapon:GetPrimaryAmmoType()
        local secondary = weapon:GetSecondaryAmmoType()
        ammoTypes[primary] = math.max( ammoTypes[primary] or 0, PRIMARY_AMMO_RESERVE )
        ammoTypes[secondary] = math.max( ammoTypes[secondary] or 0, SECONDARY_AMMO_RESERVE )
    end

    for ammoType, minimum in pairs( ammoTypes ) do
        if ammoType >= 0 then
            local reserve = math.max( minimum, game.GetAmmoMax( ammoType ) )

            local needed = reserve - ply:GetAmmoCount( ammoType )
            if needed > 0 then
                ply:GiveAmmo( needed, ammoType, true )
            end
        end
    end
end

local function getLoadout( ply )
    if ply.QuickLoadoutsWeapons ~= nil then return ply.QuickLoadoutsWeapons end

    local saved = ply:GetPData( DATA_KEY )
    if not saved then return end

    local decoded = util.JSONToTable( saved )
    if not istable( decoded ) then return end

    local selected = {}
    local count = 0
    for class, enabled in pairs( decoded ) do
        if isstring( class ) and #class <= 128 and enabled == true and count < QuickLoadouts.MaxWeapons then
            selected[class] = true
            count = count + 1
        end
    end
    ply.QuickLoadoutsWeapons = selected

    return selected
end

local function saveLoadout( ply, selected )
    if not ply:SetPData( DATA_KEY, util.TableToJSON( selected ) ) then
        return false
    end
    ply.QuickLoadoutsWeapons = selected

    return true
end

local function sendLoadout( ply, message )
    local selected = getLoadout( ply )
    net.Start( "QuickLoadouts_State" )
    net.WriteBool( selected ~= nil )
    net.WriteUInt( table.Count( selected or {} ), 7 )
    for class in pairs( selected or {} ) do
        net.WriteString( class )
    end
    net.WriteString( message or "" )
    net.Send( ply )
end

local function canSelectWeapon( ply, class )
    local weapon = list.GetEntry( "Weapon", class )
    if not weapon then return false end

    local isAdmin = ply:IsAdmin() or game.SinglePlayer()
    if ( not weapon.Spawnable or weapon.AdminOnly ) and not isAdmin then return false end

    return hook.Run( "PlayerGiveSWEP", ply, class, weapon ) == true
end

net.Receive( "QuickLoadouts_Request", function( length, ply )
    if length > MAX_REQUEST_BITS or CurTime() < ( ply.QuickLoadoutsNextRequest or 0 ) then return end
    ply.QuickLoadoutsNextRequest = CurTime() + REQUEST_INTERVAL

    if not net.ReadBool() then
        sendLoadout( ply )
        return
    end

    local class = net.ReadString()
    local enabled = net.ReadBool()
    local selected = getLoadout( ply )
    if not selected or #class == 0 or #class > 128 then return end

    if enabled and not canSelectWeapon( ply, class ) then
        sendLoadout( ply, "You cannot add that weapon to your loadout." )
        return
    end

    if enabled and not selected[class] and table.Count( selected ) >= QuickLoadouts.MaxWeapons then
        sendLoadout( ply, "Your loadout is full." )
        return
    end

    local updated = table.Copy( selected )
    updated[class] = enabled or nil
    local saved = saveLoadout( ply, updated )
    sendLoadout( ply, not saved and "Could not save your loadout. Please try again." or nil )
end )

hook.Add( "PlayerLoadout", "QuickLoadouts_ApplySelection", function( ply )
    -- Return nil so other PlayerLoadout hooks and the gamemode can handle this spawn.
    if hook.Run( "QuickLoadouts_CanApplyLoadout", ply ) == false then return end

    local selected = getLoadout( ply )
    if not selected then
        -- Run the normal gamemode loadout once to seed this player's selections.
        GAMEMODE:PlayerLoadout( ply )
        selected = {}
        for _, weapon in ipairs( ply:GetWeapons() ) do
            if table.Count( selected ) < QuickLoadouts.MaxWeapons then
                selected[weapon:GetClass()] = true
            end
        end
        local saved = saveLoadout( ply, selected )
        sendLoadout( ply, not saved and "Could not save your initial loadout." or nil )
        giveLoadoutAmmo( ply )

        return true
    end

    ply:RemoveAllAmmo()
    for class in pairs( selected ) do
        if canSelectWeapon( ply, class ) then
            ply:Give( class )
        end
    end
    giveLoadoutAmmo( ply )
    ply:SwitchToDefaultWeapon()

    -- An empty saved table deliberately suppresses the normal loadout too.
    return true
end )
