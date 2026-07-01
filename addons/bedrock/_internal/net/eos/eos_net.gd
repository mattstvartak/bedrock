extends RefCounted
## EOS P2P multiplayer transport. References EOSMultiplayerPeer directly, so the
## net backend load()s it only when GD-EOS is present. Assumes the EOS platform
## is up (an Identity login initializes and ticks it); the socket_id namespaces
## the connection, and clients reach the host by its EOS ProductUserId.

func create_server(socket_id: String):
	var peer := EOSMultiplayerPeer.new()
	if peer.create_server(socket_id) != OK:
		return null
	peer.set_is_polling(true)
	return peer


func create_client(socket_id: String, remote_user_id):
	var peer := EOSMultiplayerPeer.new()
	if peer.create_client(socket_id, remote_user_id) != OK:
		return null
	peer.set_is_polling(true)
	return peer
