class_name LobbyInfo
extends Resource
## Plain transport DTO describing a lobby, as surfaced to the game through the
## Net facade and the lobby_updated signal.

@export var id: String = ""
@export var host_name: String = ""
@export var player_count: int = 0
@export var max_players: int = 0
@export var in_progress: bool = false
@export var attributes: Dictionary = {}
