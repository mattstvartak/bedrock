class_name ISocial
extends RefCounted
## A friends/presence provider. Implemented by a PLATFORM-native source (Steam,
## console) or the canonical-account backend, NOT by EOS: EOS Friends needs an
## Epic account (Epic Account Services), which Bedrock skips by design. Lobby
## invites and lobby presence work over EOS Connect and live on the Net facade;
## this seam is specifically the cross-session friends list.

func friends() -> Array:
	return []


func presence(_user_id) -> String:
	return ""
