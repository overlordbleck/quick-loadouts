QuickLoadouts.Selected = QuickLoadouts.Selected or {}

net.Receive( "QuickLoadouts_State", function()
    QuickLoadouts.Ready = net.ReadBool()
    QuickLoadouts.Selected = {}

    for _ = 1, net.ReadUInt( 7 ) do
        QuickLoadouts.Selected[net.ReadString()] = true
    end

    local message = net.ReadString()
    if message ~= "" then
        notification.AddLegacy( message, NOTIFY_ERROR, 4 )
    end
end )

local function requestLoadout()
    net.Start( "QuickLoadouts_Request" )
    net.WriteBool( false )
    net.SendToServer()
end

hook.Add( "InitPostEntity", "QuickLoadouts_RequestSelection", requestLoadout )
hook.Add( "SpawnMenuOpen", "QuickLoadouts_RefreshSelection", requestLoadout )

function QuickLoadouts.AddButton( icon )
    if icon:GetContentType() ~= "weapon" or IsValid( icon.QuickLoadoutsButton ) then return end

    local button = vgui.Create( "DButton", icon )
    icon.QuickLoadoutsButton = button
    button:SetSize( 24, 24 )
    button:SetPos( icon:GetWide() - button:GetWide() - 4, icon:GetTall() - button:GetTall() - 23 )
    button:SetZPos( 100 )
    button:SetText( "" )
    button:SetPaintBackground( false )
    button:SetImage( "icon16/bullet_add.png" )

    button.Think = function( self )
        local selected = QuickLoadouts.Selected[icon:GetSpawnName()] == true
        self:SetEnabled( QuickLoadouts.Ready == true )

        if self.Selected == selected then return end
        self.Selected = selected
        self:SetImage( selected and "icon16/gun.png" or "icon16/add.png" )
        self:SetTooltip( selected and "Remove from spawn loadout" or "Add to spawn loadout" )
    end

    button.DoClick = function()
        if not QuickLoadouts.Ready then return end

        LocalPlayer():EmitSound( "Buttons.snd14" )

        local class = icon:GetSpawnName()
        net.Start( "QuickLoadouts_Request" )
        net.WriteBool( true )
        net.WriteString( class )
        net.WriteBool( not QuickLoadouts.Selected[class] )
        net.SendToServer()
    end
end

local function installButtons()
    local panel = vgui.GetControlTable( "ContentIcon" )
    if not panel or panel.QuickLoadoutsInstalled then return end

    -- SetSpawnName also runs when ContentIcons are copied into custom spawnlists.
    local setSpawnName = panel.SetSpawnName
    panel.SetSpawnName = function( self, class )
        setSpawnName( self, class )
        QuickLoadouts.AddButton( self )
    end
    panel.QuickLoadoutsInstalled = true
end

hook.Add( "OnGamemodeLoaded", "QuickLoadouts_InstallButtons", installButtons )
installButtons()
