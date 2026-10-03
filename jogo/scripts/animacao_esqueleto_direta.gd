@tool
extends Node
## AmberCity: passada continua, joelhos flexiveis e transicoes sem travar os ossos.
## Usar com assets/amber_motion_baked.json, formato 2, da mesma correcao.
const DADOS_MOVIMENTO: String = "res://assets/amber_motion_baked.json"
const TEMPO_TRANSICAO: float = 0.18

var personagem: CharacterBody3D = null
var esqueleto: Skeleton3D = null
var animador_importado: AnimationPlayer = null
var dados: Dictionary = {}
var ossos: Array = []
var indices: Array[int] = []
var rotacoes_repouso: Array[Quaternion] = []
var animacao_atual: String = "idle"
var tempo: float = 0.0
var funcionando: bool = false
var aviso: Label = null

var _clips: Dictionary = {}
var _raiz: int = -1
var _posicao_raiz: Vector3 = Vector3.ZERO
var _base_raiz: Basis = Basis.IDENTITY
var _fase_passada: float = 0.0
var _tempo_idle: float = 0.0
var _peso_movimento: float = 0.0
var _peso_corrida: float = 0.0
var _escala_passada: float = 1.0
var _em_salto: bool = false
var _transicao: float = TEMPO_TRANSICAO
var _origem_rotacoes: Array[Quaternion] = []
var _origem_posicao: Vector3 = Vector3.ZERO

func _ready() -> void:
    # O CharacterBody3D precisa terminar move_and_slide antes de medir a passada.
    process_priority = 10
    if not Engine.is_editor_hint():
        await get_tree().process_frame
    personagem = get_parent() as CharacterBody3D
    if personagem == null:
        _falhar("personagem ausente")
        return
    var visual: Node = personagem.get_node_or_null("Modelo_Amber")
    if visual == null:
        _falhar("modelo da Amber ausente")
        return
    if visual is Node3D:
        _escala_passada = maxf((visual as Node3D).global_basis.z.length(), 0.001)
    esqueleto = _procurar_esqueleto(visual)
    animador_importado = _procurar_animador(visual)
    if esqueleto == null:
        _falhar("reimporte assets/Amber_animada.glb")
        return
    if not FileAccess.file_exists(DADOS_MOVIMENTO):
        _falhar("arquivo amber_motion_baked.json ausente")
        return
    var bruto: Variant = JSON.parse_string(FileAccess.get_file_as_string(DADOS_MOVIMENTO))
    if not (bruto is Dictionary):
        _falhar("dados de movimento invalidos")
        return
    dados = bruto
    if int(dados.get("format_version", 0)) != 2:
        _falhar("substitua tambem assets/amber_motion_baked.json pela versao corrigida")
        return
    if not (dados.get("bones") is Array) or not (dados.get("clips") is Dictionary):
        _falhar("dados de movimento incompletos")
        return
    ossos = dados["bones"]
    for nome in ossos:
        var indice: int = esqueleto.find_bone(str(nome))
        if indice < 0:
            _falhar("osso ausente: " + str(nome))
            return
        indices.append(indice)
        rotacoes_repouso.append(esqueleto.get_bone_rest(indice).basis.get_rotation_quaternion().normalized())
    _raiz = esqueleto.find_bone(str(dados.get("root_bone", "CC_Base_Hip")))
    if _raiz < 0:
        _falhar("osso do quadril ausente")
        return
    _posicao_raiz = esqueleto.get_bone_rest(_raiz).origin
    _base_raiz = esqueleto.get_bone_rest(_raiz).basis
    for nome in ["idle", "walk", "run", "jump"]:
        if not _preparar_clip(nome):
            _falhar("animacao invalida: " + nome)
            return
    if animador_importado != null:
        animador_importado.stop()
        animador_importado.active = false
    esqueleto.show_rest_only = false
    for indice in indices:
        esqueleto.set_bone_enabled(indice, true)
    funcionando = true
    _aplicar_pose(_amostrar_pose("idle", 0.0), 1.0)

func _preparar_clip(nome: String) -> bool:
    var bruto: Variant = dados["clips"].get(nome)
    if not (bruto is Dictionary):
        return false
    var duracao: float = float(bruto.get("duration", 0.0))
    var frames: Variant = bruto.get("frames")
    var offsets: Variant = bruto.get("root_offsets")
    if duracao <= 0.0 or not (frames is Array) or not (offsets is Array):
        return false
    if frames.size() < 2 or frames.size() != offsets.size():
        return false
    var rotacoes: Array = []
    var posicoes: Array[Vector3] = []
    for f in range(frames.size()):
        if not (frames[f] is Array) or frames[f].size() != indices.size():
            return false
        if not (offsets[f] is Array) or offsets[f].size() != 3:
            return false
        var quadro: Array[Quaternion] = []
        for valores in frames[f]:
            if not (valores is Array) or valores.size() != 4:
                return false
            var q := Quaternion(float(valores[0]), float(valores[1]), float(valores[2]), float(valores[3]))
            if not q.is_finite() or q.length_squared() < 0.0001:
                return false
            quadro.append(q.normalized())
        rotacoes.append(quadro)
        var p := Vector3(float(offsets[f][0]), float(offsets[f][1]), float(offsets[f][2]))
        if not p.is_finite():
            return false
        posicoes.append(p)
    var passada: float = float(bruto.get("stride_length", 0.0))
    if nome in ["walk", "run"] and passada <= 0.0:
        return false
    _clips[nome] = {"duration": duracao, "rotations": rotacoes, "offsets": posicoes, "stride": passada}
    return true

func _physics_process(delta: float) -> void:
    if Engine.is_editor_hint() or not funcionando or personagem == null:
        return
    var real: Vector3 = personagem.get_real_velocity()
    var velocidade: float = Vector2(real.x, real.z).length()
    _avancar(delta, velocidade, not personagem.is_on_floor())

func _avancar(delta: float, velocidade: float, no_ar: bool) -> void:
    _tempo_idle += delta
    if no_ar != _em_salto:
        _iniciar_transicao()
        _em_salto = no_ar
        tempo = 0.0
    var movimento_alvo: float = smoothstep(0.04, 0.45, velocidade)
    var corrida_alvo: float = smoothstep(1.85, 2.65, velocidade)
    _peso_movimento = lerpf(_peso_movimento, movimento_alvo, 1.0 - exp(-delta * 12.0))
    _peso_corrida = lerpf(_peso_corrida, corrida_alvo, 1.0 - exp(-delta * 9.0))
    var pose: Dictionary
    if _em_salto:
        animacao_atual = "jump"
        tempo += delta
        pose = _amostrar_pose("jump", tempo)
    else:
        # A fase depende da distancia realmente percorrida; nao ha velocidade
        # minima artificial e ela nao reinicia ao alternar entre andar e correr.
        var passada: float = lerpf(float(_clips["walk"]["stride"]), float(_clips["run"]["stride"]), _peso_corrida) * _escala_passada
        _fase_passada = fposmod(_fase_passada + delta * velocidade / passada, 1.0)
        tempo = _fase_passada
        var caminhada: Dictionary = _amostrar_pose("walk", _fase_passada * float(_clips["walk"]["duration"]))
        var corrida: Dictionary = _amostrar_pose("run", _fase_passada * float(_clips["run"]["duration"]))
        var locomocao: Dictionary = _misturar_poses(caminhada, corrida, _peso_corrida)
        pose = _misturar_poses(_amostrar_pose("idle", _tempo_idle), locomocao, _peso_movimento)
        animacao_atual = "idle" if _peso_movimento < 0.05 else ("run" if _peso_corrida > 0.5 else "walk")
    _transicao = minf(_transicao + delta, TEMPO_TRANSICAO)
    _aplicar_pose(pose, smoothstep(0.0, TEMPO_TRANSICAO, _transicao))

func _amostrar_pose(nome: String, t: float) -> Dictionary:
    var clip: Dictionary = _clips[nome]
    var duracao: float = float(clip["duration"])
    var frames: Array = clip["rotations"]
    var offsets: Array = clip["offsets"]
    var tempo_clip: float = clampf(t, 0.0, duracao) if nome == "jump" else fposmod(t, duracao)
    var quadro: float = tempo_clip * float(frames.size() - 1) / duracao
    var a: int = clampi(int(floor(quadro)), 0, frames.size() - 1)
    var b: int = mini(a + 1, frames.size() - 1)
    var fracao: float = quadro - float(a)
    var rotacoes: Array[Quaternion] = []
    for i in range(indices.size()):
        var qa: Quaternion = frames[a][i]
        var qb: Quaternion = frames[b][i]
        rotacoes.append(qa.slerp(qb, fracao).normalized())
    var pa: Vector3 = offsets[a]
    var pb: Vector3 = offsets[b]
    return {"rotations": rotacoes, "offset": pa.lerp(pb, fracao)}

func _aplicar_frame(nome: String, t: float, _suavizacao: float = 1.0) -> void:
    # Mantem os botoes da cena Teste_Amber.tscn compativeis com o controlador.
    if funcionando and _clips.has(nome):
        _aplicar_pose(_amostrar_pose(nome, t), 1.0)

func _misturar_poses(a: Dictionary, b: Dictionary, peso: float) -> Dictionary:
    var rotacoes: Array[Quaternion] = []
    for i in range(indices.size()):
        var qa: Quaternion = a["rotations"][i]
        var qb: Quaternion = b["rotations"][i]
        rotacoes.append(qa.slerp(qb, peso).normalized())
    var pa: Vector3 = a["offset"]
    var pb: Vector3 = b["offset"]
    return {"rotations": rotacoes, "offset": pa.lerp(pb, peso)}

func _iniciar_transicao() -> void:
    _origem_rotacoes.clear()
    for indice in indices:
        _origem_rotacoes.append(esqueleto.get_bone_pose_rotation(indice))
    _origem_posicao = esqueleto.get_bone_pose_position(_raiz)
    _transicao = 0.0

func _aplicar_pose(pose: Dictionary, transicao: float) -> void:
    # Interpolar quadros preserva a amplitude. Filtrar novamente a pose inteira
    # a cada quadro atrasava o apoio dos pes e apagava o balanco dos bracos.
    for i in range(indices.size()):
        var delta_local: Quaternion = pose["rotations"][i]
        var alvo: Quaternion = (rotacoes_repouso[i] * delta_local).normalized()
        if transicao < 1.0 and _origem_rotacoes.size() == indices.size():
            alvo = _origem_rotacoes[i].slerp(alvo, transicao).normalized()
        esqueleto.set_bone_pose_rotation(indices[i], alvo)
    var offset: Vector3 = pose["offset"]
    var posicao: Vector3 = _posicao_raiz + _base_raiz * offset
    if transicao < 1.0 and _origem_rotacoes.size() == indices.size():
        posicao = _origem_posicao.lerp(posicao, transicao)
    esqueleto.set_bone_pose_position(_raiz, posicao)

func _procurar_esqueleto(no: Node) -> Skeleton3D:
    if no is Skeleton3D:
        return no as Skeleton3D
    for filho in no.get_children():
        var achado: Skeleton3D = _procurar_esqueleto(filho)
        if achado != null:
            return achado
    return null

func _procurar_animador(no: Node) -> AnimationPlayer:
    if no is AnimationPlayer:
        return no as AnimationPlayer
    for filho in no.get_children():
        var achado: AnimationPlayer = _procurar_animador(filho)
        if achado != null:
            return achado
    return null

func _falhar(texto: String) -> void:
    funcionando = false
    if not Engine.is_editor_hint():
        if aviso == null:
            var camada := CanvasLayer.new()
            camada.name = "DiagnosticoAmber"
            add_child(camada)
            aviso = Label.new()
            aviso.position = Vector2(12, 10)
            aviso.add_theme_color_override("font_color", Color(1.0, 0.55, 0.4))
            aviso.add_theme_font_size_override("font_size", 15)
            camada.add_child(aviso)
        aviso.text = "AMBER: " + texto
        aviso.visible = true
    push_error("AmberCity: " + texto)
