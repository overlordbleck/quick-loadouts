# Quick Loadouts

Click the **plus icon** button in the top-right corner of a weapon's spawnmenu icon to add weapons to your loadout.

On your first spawn, the normal gamemode loadout becomes your initial selection. Default weapons
remain selected until you remove them. Saved selections replace the default loadout on subsequent
spawns; removing every weapon produces an empty loadout. Changes apply on respawn, not immediately.
Selections persist per player on the server, with a maximum of 64 weapons.

The server checks spawnability, admin restrictions, and `PlayerGiveSWEP` permissions when adding
weapons and again when granting them. Removed or newly restricted weapons remain selected but are
not granted. On spawn, primary and secondary reserve ammo used by the granted weapons is topped up
to at least 256 rounds for primary ammo and 5 for secondary ammo, or the ammo type's normal capacity
if higher. Shared ammo types use the higher target and are topped up once. Weapons without ammo are skipped. Server ammo limits
still apply.

Designed for Sandbox and derived gamemodes using `ContentIcon` and `PlayerLoadout`. Other addons
that override loadouts or replace the icon's `SetSpawnName` method may conflict.
