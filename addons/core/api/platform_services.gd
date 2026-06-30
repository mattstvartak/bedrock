extends Node
## Platform — the service locator.
##
## Binds each public interface to a concrete backend at boot, chosen by build
## target. Modules ask Platform for their backend, so nothing in game code (or
## in another module) hardcodes EOS or any platform SDK. Console-certified
## backends slot in here later without touching game code.

enum Target { STANDALONE, STEAM, EPIC, PS5, XBOX, SWITCH }

# Interface keys. Backends are registered and looked up by these.
const IDENTITY := &"identity"
const SAVE := &"save"
const NET := &"net"
const ACHIEVEMENTS := &"achievements"
const STORE := &"store"
const VOICE := &"voice"

var target: Target = Target.STANDALONE

var _backends: Dictionary = {}  ## StringName -> Object (interface impl)


func _ready() -> void:
	target = detect_target()
	_bootstrap()


## Desktop detection now. Console targets are resolved by export feature tags
## once those builds exist; left as STANDALONE until then.
func detect_target() -> Target:
	if OS.has_feature("steam"):
		return Target.STEAM
	if OS.has_feature("epic"):
		return Target.EPIC
	return Target.STANDALONE


## Instantiate and bind the backends for this target. Empty until the modules
## (identity, save, net, ...) land; each will bind its impl here behind its
## interface. Facades resolve lazily, so binding can also happen after _ready.
func _bootstrap() -> void:
	pass


func bind(key: StringName, impl: Object) -> void:
	_backends[key] = impl


func get_backend(key: StringName) -> Object:
	return _backends.get(key)


func has_backend(key: StringName) -> bool:
	return _backends.has(key)
