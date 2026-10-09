extends Node
## CoreEvents — the global signal bus.
##
## Base-to-game communication flows through here so games never hold a reference
## into addons/core/_internal. A game connects to these signals; it does not
## reach into the modules that emit them.

# --- Identity ---
signal identity_changed(account)        ## AccountInfo, or null on logout
signal identity_login_failed(reason)    ## String

# --- Save ---
signal save_written(slot)               ## int
signal save_loaded(slot)                ## int
signal save_failed(slot, reason)        ## int, String
signal sync_started(slot)               ## int
signal sync_completed(slot)             ## int
signal sync_failed(slot, reason)        ## int, String
## Cloud and local disagree. The game resolves, or the configured policy applies.
signal sync_conflict(slot, local, remote)  ## int, SaveData, SaveData

# --- Net / lobbies ---
signal lobby_updated(lobby)             ## LobbyInfo
signal lobby_left()
signal peer_joined(peer_id)             ## int
signal peer_left(peer_id)               ## int
signal net_error(reason)                ## String
