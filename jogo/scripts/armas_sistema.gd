class_name ArmasSistema
extends Node3D
## Sistema de armas de AmberCity: mira, disparo por raycast, armas corpo a corpo,
## flash, tracers, som procedural e integração com a IA emocional dos moradores.
## O jogador só usa armas COMPRADAS na Loja de Armas (scripts/loja_armas.gd).

const LOJA_DATA = preload("res://scripts/loja_armas.gd")
static func _loja_obter(id: String) -> Dictionary:
    return LOJA_DATA.obter(id)

var arma_atual: Dictionary = _loja_obter("pistola")
var cooldown: float = 0.0
var dinheiro: int = 600            # dá pra começar com a pistola comprada
var armas_compradas: Array[String] = ["punho", "pistola"]
var disparando: bool = false       # segurar o dedo em armas automáticas
var ultimo_feedback: String = ""
var _tempo_feedback: float = 0.0
var flash_luz: OmniLight3D = null
var flash_mesh: MeshInstance3D = null
var _flash_tempo: float = 0.0
var audio_player: AudioStreamPlayer = null
var mira: Control = null            # reticulo desenhado pelo HUD (hud_analogicos)
var _tecla_disparo: bool = false    # mouse pressionado no PC
var _dedo_disparo: int = -1         # dedo do celular no botao de tiro
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    randomize()
    _criar_flash()
    _montar_audio()

# ---------------- CONTROLE DE TIRO (HUD chama estas funcoes) ----------------
func set_mira(controle: Control) -> void:
    mira = controle

## Aponta na direcao da camera e dispara (um toque = um tiro; armas auto
## continuam enquanto o dedo ficar na tela, via _process).
func disparar() -> void:
    atirar()

func teclado_disparo(pressionado: bool) -> void:
    _tecla_disparo = pressionado
    disparando = pressionado or _dedo_disparo != -1
    if pressionado:
        atirar()

func toque_disparo(indice: int, pressionado: bool) -> void:
    if pressionado:
        _dedo_disparo = indice
        disparando = true
        atirar()
    elif indice == _dedo_disparo:
        _dedo_disparo = -1
        disparando = _tecla_disparo

func _criar_flash() -> void:
    flash_luz = OmniLight3D.new()
    flash_luz.name = "FlashTiro"
    flash_luz.light_color = Color(1.0, 0.85, 0.5)
    flash_luz.light_energy = 0.0
    flash_luz.omni_range = 6.0
    flash_luz.shadow_enabled = false
    add_child(flash_luz)
    flash_mesh = MeshInstance3D.new()
    flash_mesh.name = "Clarao"
    var esfera := SphereMesh.new()
    esfera.radius = 0.06
    esfera.height = 0.12
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color(1.0, 0.9, 0.6, 0.9)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.emission_enabled = true
    mat.emission = Color(1.0, 0.85, 0.45)
    mat.emission_energy_multiplier = 4.0
    esfera.material = mat
    flash_mesh.mesh = esfera
    flash_mesh.visible = false
    add_child(flash_mesh)

# Som 100% procedural (não precisa de arquivos de áudio no Android).
func _montar_audio() -> void:
    if not AudioServer.get_bus_index("Master") >= 0:
        return
    audio_player = AudioStreamPlayer.new()
    audio_player.name = "SomTiro"
    add_child(audio_player)

func _process(delta: float) -> void:
    cooldown -= delta
    _tempo_feedback -= delta
    if _flash_tempo > 0.0:
        _flash_tempo -= delta
        flash_luz.light_energy = maxf(0.0, _flash_tempo * 60.0)
        flash_mesh.visible = _flash_tempo > 0.0
    # Recarga automática enquanto o dedo continua na tela (armas auto).
    if disparando and cooldown <= 0.0 and bool(arma_atual.get("auto", false)):
        atirar()

func definir_arma(id: String) -> bool:
    if id in armas_compradas:
        arma_atual = _loja_obter(id)
        ultimo_feedback = arma_atual["nome"]
        _tempo_feedback = 2.0
        return true
    return false

func comprar(id: String) -> String:
    var arma: Dictionary = _loja_obter(id)
    if id in armas_compradas:
        definir_arma(id)
        return "já_tem"
    if dinheiro < int(arma["custo"]):
        return "sem_dinheiro"
    dinheiro -= int(arma["custo"])
    armas_compradas.append(id)
    definir_arma(id)
    return "ok"

# ---------------- DISPARO ----------------
func atirar() -> void:
    if cooldown > 0.0:
        return
    cooldown = float(arma_atual["cadencia"])
    var camera: Camera3D = get_viewport().get_camera_3d()
    if camera == null:
        return
    var origem: Vector3 = camera.global_position
    var direcao: Vector3 = -camera.global_basis.z.normalized()
    var alcance: float = float(arma_atual["alcance"])

    if alcance <= 4.0:
        _golpe_corpo_a_corpo(origem, direcao)
        return

    # Raycast contra cenário (paredes/prédios).
    var space := get_world_3d().direct_space_state
    var fim := origem + direcao * alcance
    var query := PhysicsRayQueryParameters3D.create(origem, fim)
    var _cena_atual := get_tree().current_scene
    var _amber_node: Node = (_cena_atual.find_child("Amber", true, false) if _cena_atual != null else null)
    if _amber_node != null:
        query.exclude = [_amber_node]   # nao acertar a propria Amber
    var resultado := space.intersect_ray(query)
    var ponto_fim: Vector3 = fim
    if not resultado.is_empty():
        ponto_fim = resultado["position"]

    # Alvo: morador atingido pela linha de tiro antes do impacto na parede.
    var multidao := _achar_multidao()
    var alvo: Node3D = null
    if multidao != null:
        alvo = multidao.call("morador_no_segmento", origem, direcao, origem.distance_to(ponto_fim))
    if alvo != null and alvo.has_method("aplicar_dano"):
        alvo.aplicar_dano(float(arma_atual["dano"]), origem, self, false)
        var grito: String = alvo.call("gritar_dor") if alvo.has_method("gritar_dor") else "AI!"
        ultimo_feedback = "%s (%s)" % [String(alvo.get("ia").nome) if alvo.get("ia") != null else "Morador", grito]
        _tempo_feedback = 2.5
    _tracer(origem + direcao * 0.4, ponto_fim)
    _som_tiro(false)

func _golpe_corpo_a_corpo(origem: Vector3, direcao: Vector3) -> void:
    var multidao := _achar_multidao()
    if multidao == null:
        return
    var peito := origem + Vector3(0, 1.2, 0)
    var alvo: Node3D = multidao.call("morador_proximo", peito, direcao, float(arma_atual["alcance"]))
    if alvo != null and alvo.has_method("aplicar_dano"):
        var faca: bool = String(arma_atual["id"]) == "faca"
        alvo.aplicar_dano(float(arma_atual["dano"]), origem, self, true)
        ultimo_feedback = "Golpe! " + (String(alvo.call("gritar_dor")) if alvo.has_method("gritar_dor") else "Ai!")
        _tempo_feedback = 2.0
    _som_tiro(true)

func _achar_multidao() -> Node:
    var cidade := get_tree().current_scene
    var direto := cidade.find_child("Multidao_Cidade", true, false) if cidade != null else null
    if direto == null:
        direto = get_tree().get_first_node_in_group("multidao")
    return direto

# Linha luminosa curta mostrando a trajetória da bala.
func _tracer(de: Vector3, ate: Vector3) -> void:
    var tracer := Line3D.new()
    tracer.name = "Tracer"
    tracer.points = PackedVector3Array([de, ate])
    add_child(tracer)
    var t := create_timer(0.07)
    t.timeout.connect(func(): if is_instance_valid(tracer): tracer.queue_free())

# Luz e clarão na boca do cano.
func _flash_na_mira() -> void:
    var camera: Camera3D = get_viewport().get_camera_3d()
    if camera == null:
        return
    var ponto := camera.global_position - camera.global_basis.z * 0.5 + camera.global_basis.x * 0.18
    flash_luz.position = ponto
    flash_mesh.position = ponto
    _flash_tempo = 0.06

# Som sintetizado: "tump" grave p/ tiro, "toc" abafado p/ golpe.
func _som_tiro(corpo_a_corpo: bool) -> void:
    _flash_na_mira()
    if audio_player == null:
        return
    var taxa := 44100
    var dur := 0.16 if not corpo_a_corpo else 0.08
    var n := int(taxa * dur)
    var amostras := AudioSampleBuffer.new(n, 1, taxa)
    for i in range(n):
        var t := float(i) / float(taxa)
        var env := exp(-t * (14.0 if not corpo_a_corpo else 40.0))
        var f := 110.0 if not corpo_a_corpo else 60.0
        var s := sin(TAU * f * t) * 0.6 + (_rng.randf() * 2.0 - 1.0) * 0.4
        amostras.set_channel(i, 0, s * env * 0.5)
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = taxa
    stream.data = amostras.save_to_wav_buffer()
    audio_player.stream = stream
    audio_player.play()

class Line3D extends MeshInstance3D:
    var points: PackedVector3Array = PackedVector3Array():
        set(v):
            points = v
            var mesh := ImmediateMesh.new()
            if v.size() >= 2:
                mesh.surface_begin(Mesh.PRIMITIVE_LINES)
                var mat := StandardMaterial3D.new()
                mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                mat.emission_enabled = true
                mat.emission = Color(1.0, 0.95, 0.6)
                mat.emission_energy_multiplier = 3.0
                mat.albedo_color = Color(1, 0.95, 0.6, 0.85)
                mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                surface_material_override = mat
                cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                for p in v:
                    mesh.surface_add_vertex(p)
                mesh.surface_end()
            self.mesh = mesh
