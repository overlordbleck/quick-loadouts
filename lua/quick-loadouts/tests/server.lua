-- Run in a development server console: lua_openscript quick-loadouts/tests/server.lua
-- Uses isolated mocks; does not change real players, networking, hooks, or saved data.
local callbacks = {}
local incoming = {}
local now = 0
local failSave = false
local denied = false
local defaults = 0
local ammoLimits = { [1] = 100, [2] = 5 }
local weaponList = {
    weapon_pistol = { Spawnable = true },
    weapon_shotgun = { Spawnable = true },
    weapon_admin = { Spawnable = true, AdminOnly = true }
}
local function noop() end
local function readValue()
    return table.remove( incoming, 1 )
end

local environment = setmetatable( {
    QuickLoadouts = { MaxWeapons = 64 },
    CurTime = function() return now end,
    game = {
        SinglePlayer = function() return false end,
        GetAmmoMax = function( ammoType )
            assert( ammoType >= 0, "Queried an invalid ammo type" )

            return ammoLimits[ammoType] or -1
        end
    },
    list = { GetEntry = function( _, class ) return weaponList[class] end },
    util = {
        AddNetworkString = noop,
        TableToJSON = util.TableToJSON,
        JSONToTable = util.JSONToTable
    },
    net = {
        Receive = function( name, callback ) callbacks[name] = callback end,
        ReadBool = readValue,
        ReadString = readValue,
        Start = noop, WriteBool = noop, WriteString = noop, WriteUInt = noop, Send = noop
    },
    hook = {
        Add = function( event, _, callback ) callbacks[event] = callback end,
        Run = function() return not denied end
    },
    GAMEMODE = {
        PlayerLoadout = function( _, ply )
            defaults = defaults + 1
            ply:Give( "weapon_pistol" )
        end
    }
}, { __index = _G } )

local chunk = assert( CompileFile( "quick-loadouts/server/sv_quickloadouts.lua" ) )
setfenv( chunk, environment )()

local ply = { weapons = {}, ammo = {}, ammoGrants = {} }
function ply:GetPData() return self.saved end
function ply:SetPData( _, value )
    if failSave then return false end
    self.saved = value

    return true
end
function ply:IsAdmin() return false end
function ply:Give( class )
    self.weapons[#self.weapons + 1] = {
        GetClass = function() return class end,
        GetPrimaryAmmoType = function() return 1 end,
        GetSecondaryAmmoType = function() return class == "weapon_shotgun" and 2 or -1 end
    }
    self.ammo[1] = ( self.ammo[1] or 0 ) + 10
end
function ply:GetWeapons() return self.weapons end
function ply:GetAmmoCount( ammoType ) return self.ammo[ammoType] or 0 end
function ply:GiveAmmo( amount, ammoType )
    self.ammo[ammoType] = self:GetAmmoCount( ammoType ) + amount
    self.ammoGrants[ammoType] = ( self.ammoGrants[ammoType] or 0 ) + 1
end
function ply:RemoveAllAmmo() self.ammo = {} end
ply.SwitchToDefaultWeapon = noop

local function spawn()
    ply.weapons = {}
    ply.ammoGrants = {}
    assert( callbacks.PlayerLoadout( ply ) == true )
end

local function selectWeapon( class, enabled )
    now = now + 1
    incoming = { true, class, enabled }
    callbacks.QuickLoadouts_Request( 200, ply )
end

spawn()
assert( defaults == 1 and ply.QuickLoadoutsWeapons.weapon_pistol, "Default loadout was not seeded" )
assert( ply.ammo[1] == 256 and ply.ammo[-1] == nil, "Initial ammo top-up failed" )
selectWeapon( "weapon_pistol", false )
ply.QuickLoadoutsWeapons = nil -- Simulate reconnect: read the saved empty selection.
spawn()
assert( #ply.weapons == 0 and defaults == 1, "Empty loadout restored the defaults" )
assert( next( ply.ammo ) == nil, "Empty loadout received ammo" )
selectWeapon( "weapon_shotgun", true )
spawn()
assert( #ply.weapons == 1 and ply.weapons[1]:GetClass() == "weapon_shotgun", "Selection was not applied" )
assert( ply.ammo[1] == 256 and ply.ammo[2] == 5, "Primary or secondary ammo was not supplied" )
selectWeapon( "weapon_pistol", true )
spawn()
assert( ply.ammo[1] == 256 and ply.ammoGrants[1] == 1, "Shared ammo was granted twice" )
ammoLimits[2] = -1
spawn()
assert( ply.ammo[2] == 5, "Secondary ammo minimum failed" )
ammoLimits[1] = 300
ammoLimits[2] = 10
spawn()
assert( ply.ammo[1] == 300 and ply.ammo[2] == 10, "Higher default ammo capacities were ignored" )
selectWeapon( "weapon_pistol", false )
selectWeapon( "weapon_admin", true )
selectWeapon( "not_a_weapon", true )
assert( table.Count( ply.QuickLoadoutsWeapons ) == 1, "Unauthorized weapon was accepted" )
denied = true
spawn()
assert( #ply.weapons == 0, "Respawn bypassed weapon permissions" )
assert( next( ply.ammo ) == nil, "Denied weapons received ammo" )
denied = false
failSave = true
selectWeapon( "weapon_shotgun", false )
assert( ply.QuickLoadoutsWeapons.weapon_shotgun, "Failed save changed the active selection" )
print( "[Quick Loadouts] Server checks passed." )
