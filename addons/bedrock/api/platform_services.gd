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

const _LocalSaveBackend := preload("res://addons/bedrock/_internal/save/local_save_backend.gd")
const _EOSConnectIdentity := preload("res://addons/bedrock/_internal/identity/eos_connect_identity.gd")
const _EOS_GATEWAY_PATH := "res://addons/bedrock/_internal/eos/eos_gateway.gd"

var target: Target = Target.STANDALONE

## A game sets this directly, or ships one at res://game_config.tres. Defaults
## are used if neither is present.
var config: GameConfig

var _backends: Dictionary = {}  ## StringName -> Object (interface impl)


func _ready() -> void:
	target = detect_target()
	if config == null:
		config = _load_config()
	_bootstrap()


## Desktop detection now. Console targets are resolved by export feature tags
## once those builds exist; left as STANDALONE until then.
func detect_target() -> Target:
	if OS.has_feature("steam"):
		return Target.STEAM
	if OS.has_feature("epic"):
		return Target.EPIC
	return Target.STANDALONE


func _load_config() -> GameConfig:
	var path := "res://game_config.tres"
	if ResourceLoader.exists(path):
		return load(path) as GameConfig
	return GameConfig.new()


## Instantiate and bind the platform-divergent backends (save, identity, net,
## ...) for this target + config. The self-contained services (audio, settings,
## scenes, input, locale) are their own autoloads and don't bind here. Facades
## resolve lazily, so a backend can also be bound after _ready.
func _bootstrap() -> void:
	if config.enable_save:
		bind(SAVE, _LocalSaveBackend.new())

	# Identity via EOS Connect, only when the GD-EOS addon is present. The gateway
	# is load()ed (not preloaded) so the base still imports without GD-EOS. It's a
	# child node so it can tick the EOS platform, and stays idle (no init, no
	# network) until a login is actually requested.
	if config.enable_identity and ClassDB.class_exists("EOSConnect"):
		var gateway: Node = load(_EOS_GATEWAY_PATH).new()
		add_child(gateway)
		bind(IDENTITY, _EOSConnectIdentity.new(gateway))


func bind(key: StringName, impl: Object) -> void:
	_backends[key] = impl


func get_backend(key: StringName) -> Object:
	return _backends.get(key)


func has_backend(key: StringName) -> bool:
	return _backends.has(key)
