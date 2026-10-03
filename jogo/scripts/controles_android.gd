extends CanvasLayer
## HUD Android. A voz toca UMA vez, apos cinco segundos de jogo.
const ESPERA_VOZ_SEGUNDOS: float = 5.0
var _voz: AudioStreamPlayer = null
var _timer_voz: Timer = null
var _audio_amber := preload("res://assets/audio/amber_bella.mp3")

func _ready() -> void:
    if OS.has_feature("android") or OS.has_feature("ios"):
        DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
    _voz = AudioStreamPlayer.new()
    _voz.name = "VozAmber"
    _voz.stream = _audio_amber
    add_child(_voz)
    var hud: Control = Control.new()
    hud.name = "HUD"
    hud.set_script(preload("res://scripts/hud_analogicos.gd"))
    add_child(hud)
    # Nenhum play() em _ready: a contagem comeca quando a cena inicia.
    _timer_voz = Timer.new()
    _timer_voz.name = "EsperaCincoSegundos"
    _timer_voz.one_shot = true
    _timer_voz.process_mode = Node.PROCESS_MODE_PAUSABLE
    _timer_voz.wait_time = ESPERA_VOZ_SEGUNDOS
    add_child(_timer_voz)
    _timer_voz.timeout.connect(_tocar_fala_inicial)
    _timer_voz.start()

func _tocar_fala_inicial() -> void:
    if is_instance_valid(_voz) and _voz.stream != null:
        _voz.play()
