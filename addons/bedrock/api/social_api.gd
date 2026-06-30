extends Node
## Social — invites and friends.
##
## Lobby invites work over EOS Connect (no Epic account), so invite_to_lobby just
## forwards to the Net/lobby layer. A FRIENDS LIST does not come from EOS (EOS
## Friends needs Epic Account Services, which Bedrock skips); it comes from a
## platform-native source (Steam/console) or the canonical-account backend behind
## ISocial. Until such a provider is bound, friends() returns an empty list.

var _backend


func invite_to_lobby(target_user_id) -> bool:
	return Net.invite_to_lobby(target_user_id)


func friends() -> Array:
	var p = _resolve()
	return p.friends() if p else []


func presence(user_id) -> String:
	var p = _resolve()
	return p.presence(user_id) if p else ""


func _resolve():
	if _backend == null and Platform.has_backend(Platform.SOCIAL):
		_backend = Platform.get_backend(Platform.SOCIAL)
	return _backend
