include( "quick-loadouts/sh_quickloadouts.lua" )

if SERVER then
    AddCSLuaFile( "quick-loadouts/sh_quickloadouts.lua" )
    AddCSLuaFile( "quick-loadouts/client/cl_quickloadouts.lua" )
    include( "quick-loadouts/server/sv_quickloadouts.lua" )
else
    include( "quick-loadouts/client/cl_quickloadouts.lua" )
end
