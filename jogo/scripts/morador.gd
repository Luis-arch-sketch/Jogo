extends Node3D
## Morador da cidade AmberCity: personagem humanoide que vaga pelas calçadas.
## Usa a MESMA animação de caminhada biomecânica real da Amber
## (assets/amber_motion_baked.json), apenas com cadência proporcional
## à altura e velocidade do morador.

const RUA: float = 9.2
const MEIO_RUA: float = RUA * 0.5
const CALCADA: float = 1.6
const MARGEM: float = 247.0          # limites do mapa (500 x 500 m)
const PASSO_POR_ALTURA: float = 0.71 # passada ≈ 0.71 × altura (dado real de marcha)
const GRAVIDADE: float = 18.0

var perfil: Dictionary = {}
var velocidade_alvo: float = 1.35
var fase_passada: float = 0.0
var peso_movimento: float = 0.0
var estado: String = "andando"       # andando | pausado
var tempo_pausa: float = 0.0
var proxima_pausa: float = 12.0
var direcao_atual: Vector3 = Vector3.FORWARD
var destino: Vector3 = Vector3.ZERO
var pos_y: float = 0.0
var vel_y: float = 0.0

# Partes do corpo (criadas em _montar).
var raiz: Node3D                    # quadril
var toraco: Node3D
var cabeca: Node3D
var ombro_e: Node3D; var cotovelo_e: Node3D
var ombro_d: Node3D; var cotovelo_d: Node3D
var quadril_e: Node3D; var joelho_e: Node3D; tornozelo_e: Node3D
var quadril_d: Node3D; var joelho_d: Node3D; tornozelo_d: Node3D

var clips: Dictionary = {}   # walk/idle carregados do bake da Amber
var carregado: bool = false

func configurar(dados: Dictionary, inicial: Vector3, json_animacao: Variant = null) -> void:
    perfil = dados
    if json_animacao is Dictionary:
        _interpretar_clips(json_animacao)
    velocidade_alvo = float(dados.get("velocidade", 1.35))
    fase_passada = float(dados.get("fase", 0.0))
    position = inicial
    destino = _novo_destino()

func _ready() -> void:
    _carregar_clips()
    _montar_corpo()
    randomize()
    proxima_pausa = randf_range(float(perfil.get("pausa_min", 4.0)), float(perfil.get("pausa_max", 15.0)))

func _carregar_clips() -> void:
    if carregado:
        return
    var caminho := "res://assets/amber_motion_baked.json"
    if not FileAccess.file_exists(caminho):
        return
    var bruto: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
    _interpretar_clips(bruto)

func _interpretar_clips(bruto: Variant) -> void:
    if carregado or not (bruto is Dictionary):
        return
    carregado = true
    var d: Dictionary = bruto
    var bones: Array = d.get("bones", [])
    # Ossos do bake da Amber usados pelos moradores (mesma animação real).
    var nomes_ossos: Array[String] = [
        "CC_Base_NeckTwist01",   # 0 cabeça/pescoço
        "CC_Base_L_Upperarm",    # 1 ombro esquerdo
        "CC_Base_R_Upperarm",    # 2 ombro direito
        "CC_Base_L_Forearm",     # 3 cotovelo esquerdo
        "CC_Base_R_Forearm",     # 4 cotovelo direito
        "CC_Base_L_Thigh",       # 5 quadril esquerdo
        "CC_Base_R_Thigh",       # 6 quadril direito
        "CC_Base_L_Calf",        # 7 joelho esquerdo
        "CC_Base_R_Calf",        # 8 joelho direito
        "CC_Base_L_Foot",        # 9 tornozelo esquerdo
        "CC_Base_R_Foot",        # 10 tornozelo direito
    ]
    var indices: Array[int] = []
    for n in nomes_ossos:
        indices.append(bones.find(n))
    for nome in ["idle", "walk"]:
        var clip_bruto: Variant = (d.get("clips", {}) as Dictionary).get(nome)
        if not (clip_bruto is Dictionary):
            continue
        var frames: Array = clip_bruto.get("frames", [])
        var duracao: float = float(clip_bruto.get("duration", 1.0))
        var amostras: Array[float] = []
        var stride: float = float(clip_bruto.get("stride_length", 1.4))
        for f in range(frames.size()):
            var quadro: Array = frames[f]
            for k in range(indices.size()):
                var i: int = indices[k]
                if i >= 0 and i < quadro.size():
                    amostras.append(_angulo_x(quadro[i]))
                else:
                    amostras.append(0.0)
        clips[nome] = {"duracao": duracao, "amostras": amostras, "por_quadro": indices.size(), "stride": stride}

# Converte quaternion do bake em ângulo Euler aproximado no eixo pedido.
func _euler(q: Array) -> Vector3:
    var x: float = float(q[0]); var y: float = float(q[1]); var z: float = float(q[2]); var w: float = float(q[3])
    var sx: float = atan2f(2.0 * (w * x - y * z), 1.0 - 2.0 * (x * x + y * y))
    var sy: float = asinf(clampf(2.0 * (w * y + z * x), -1.0, 1.0))
    var sz: float = atan2f(2.0 * (w * z - x * y), 1.0 - 2.0 * (y * y + z * z))
    return Vector3(sx, sy, sz)

func _angulo_x(q: Variant) -> float:
    if not (q is Array) or (q as Array).size() < 4:
        return 0.0
    return _euler(q).x

func _angulo_z(q: Variant) -> float:
    if not (q is Array) or (q as Array).size() < 4:
        return 0.0
    return _euler(q).z

func _cor(cor: Variant, padrao: Color) -> Color:
    if cor is Array and (cor as Array).size() >= 3:
        return Color(float(cor[0]), float(cor[1]), float(cor[2]))
    return padrao

func _mat(cor: Color, rugosidade: float = 0.85) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = cor
    m.roughness = rugosidade
    m.metallic = 0.0
    return m

func _peca(pai: Node3D, local: Vector3, tamanho: Vector3, material: Material, nome: String = "") -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    if nome != "":
        mi.name = nome
    var mesh := BoxMesh.new()
    mesh.size = tamanho
    mesh.material = material
    mi.mesh = mesh
    mi.position = local
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    pai.add_child(mi)
    return mi

func _no(pai: Node3D, local: Vector3, nome: String) -> Node3D:
    var n := Node3D.new()
    n.name = nome
    n.position = local
    pai.add_child(n)
    return n

func _montar_corpo() -> void:
    var h: float = float(perfil.get("altura", 1.70))
    var largura_fator: float = float(perfil.get("largura", 1.0))
    var magreza: float = float(perfil.get("magreza", 1.0))
    var escala: float = h / 1.70

    var pele := _mat(_cor(perfil.get("cor_pele", null), Color(0.8, 0.62, 0.5)))
    var cabelo := _mat(_cor(perfil.get("cor_cabelo", null), Color(0.15, 0.12, 0.1)), 0.7)
    var camisa := _mat(_cor(perfil.get("cor_camisa", null), Color(0.5, 0.5, 0.55)))
    var calca := _mat(_cor(perfil.get("cor_calca", null), Color(0.25, 0.26, 0.3)))
    var sapato := _mat(_cor(perfil.get("cor_sapato", null), Color(0.12, 0.11, 0.1)))

    var cintura: float = 0.55 * escala
    var ombro: float = 1.42 * escala
    var braco: float = 0.30 * escala
    var perna_sup: float = 0.42 * escala
    var perna_inf: float = 0.42 * escala
    var pescoco: float = 0.10 * escala
    var cabeca_r: float = 0.115 * escala
    var ombros_larg: float = 0.40 * escala * largura_fator
    var tronco_larg: float = 0.34 * escala * largura_fator / maxf(magreza, 0.6)
    var braço_comp: float = 0.58 * escala
    var coxa_larg: float = 0.15 * escala * sqrt(largura_fator) / maxf(sqrt(magreza), 0.7)

    raiz = _no(self, Vector3(0, cintura, 0), "Quadril")
    quadril_e = _no(raiz, Vector3(-0.09 * escala, -0.02, 0), "QuadrilE")
    joelho_e = _no(quadril_e, Vector3(0, -perna_sup, 0), "JoelhoE")
    tornozelo_e = _no(joelho_e, Vector3(0, -perna_inf, 0), "TornozeloE")
    quadril_d = _no(raiz, Vector3(0.09 * escala, -0.02, 0), "QuadrilD")
    joelho_d = _no(quadril_d, Vector3(0, -perna_sup, 0), "JoelhoD")
    tornozelo_d = _no(joelho_d, Vector3(0, -perna_inf, 0), "TornozeloD")

    toraco = _no(raiz, Vector3(0, 0.05, 0), "Toraco")
    _peca(toraco, Vector3(0, (ombro - cintura) * 0.55, 0), Vector3(tronco_larg, ombro - cintura, tronco_larg * 0.55), camisa, "Camisa")
    ombro_e = _no(toraco, Vector3(-(ombros_larg * 0.5 + braço_comp * 0.12), ombro - cintura - 0.03 * escala, 0), "OmbroE")
    cotovelo_e = _no(ombro_e, Vector3(0, -braco, 0), "CotoveloE")
    ombro_d = _no(toraco, Vector3((ombros_larg * 0.5 + braço_comp * 0.12), ombro - cintura - 0.03 * escala, 0), "OmbroD")
    cotovelo_d = _no(ombro_d, Vector3(0, -braco, 0), "CotoveloD")
    cabeca = _no(toraco, Vector3(0, ombro - cintura + pescoco + cabeca_r, 0), "Cabeca")

    # Pernas e braços (malhas presas aos nós-pivô).
    _peca(quadril_e, Vector3(0, -perna_sup * 0.5, 0), Vector3(coxa_larg, perna_sup, coxa_larg), calca, "CoxaE")
    _peca(joelho_e, Vector3(0, -perna_inf * 0.5, 0), Vector3(coxa_larg * 0.85, perna_inf, coxa_larg * 0.85), calca, "CanelaE")
    _peca(tornozelo_e, Vector3(0, -0.045 * escala, -0.06 * escala), Vector3(coxa_larg * 0.9, 0.09 * escala, 0.22 * escala), sapato, "PeE")
    _peca(quadril_d, Vector3(0, -perna_sup * 0.5, 0), Vector3(coxa_larg, perna_sup, coxa_larg), calca, "CoxaD")
    _peca(joelho_d, Vector3(0, -perna_inf * 0.5, 0), Vector3(coxa_larg * 0.85, perna_inf, coxa_larg * 0.85), calca, "CanelaD")
    _peca(tornozelo_d, Vector3(0, -0.045 * escala, -0.06 * escala), Vector3(coxa_larg * 0.9, 0.09 * escala, 0.22 * escala), sapato, "PeD")
    _peca(ombro_e, Vector3(0, -braco * 0.5, 0), Vector3(braco * 0.42, braco, braco * 0.42), camisa, "BracoE")
    _peca(cotovelo_e, Vector3(0, -braco * 0.5, 0), Vector3(braco * 0.36, braco, braco * 0.36), pele, "AntebracoE")
    _peca(ombro_d, Vector3(0, -braco * 0.5, 0), Vector3(braco * 0.42, braco, braco * 0.42), camisa, "BracoD")
    _peca(cotovelo_d, Vector3(0, -braco * 0.5, 0), Vector3(braco * 0.36, braco, braco * 0.36), pele, "AntebracoD")

    var cabeca_mesh := _peca(cabeca, Vector3.ZERO, Vector3(cabeca_r * 1.7, cabeca_r * 2.1, cabeca_r * 1.7), pele, "CabecaVisual")
    cabeca_mesh.scale = Vector3.ONE
    _peca(cabeca, Vector3(0, cabeca_r * 0.75, cabeca_r * 0.15), Vector3(cabeca_r * 1.85, cabeca_r * 0.85, cabeca_r * 1.6), cabelo, "CabeloTopo")
    if bool(perfil.get("cabelo_comprido", false)):
        _peca(cabeca, Vector3(0, -cabeca_r * 0.6, cabeca_r * 0.75), Vector3(cabeca_r * 1.5, cabeca_r * 2.4, cabeca_r * 0.5), cabelo, "CabeloComprido")

func _novo_destino() -> Vector3:
    # Destinos sobre o traçado de ruas (múltiplos de 9.6 m) com calçada lateral.
    var grade: float = 96.0
    var linhas: Array[int] = [-2, -1, 0, 1, 2]
    var escolha_eixo: int = randi() % 2
    var l1: int = linhas[randi() % linhas.size()]
    var p_eixo: float = l1 * grade + (MEIO_RUA + CALCADA * 0.5) * (1.0 if randi() % 2 == 0 else -1.0)
    var ao_longo: float = float(randi_range(-int(MARGEM / grade), int(MARGEM / grade))) * grade
    var alvo: Vector3
    if escolha_eixo == 0:
        alvo = Vector3(ao_longo, 0.0, p_eixo)
    else:
        alvo = Vector3(p_eixo, 0.0, ao_longo)
    alvo.x = clampf(alvo.x, -MARGEM, MARGEM)
    alvo.z = clampf(alvo.z, -MARGEM, MARGEM)
    return alvo

func _physics_process(delta: float) -> void:
    if raiz == null:
        return
    if not visible:
        return
    if estado == "pausado":
        tempo_pausa -= delta
        if tempo_pausa <= 0.0:
            estado = "andando"
            destino = _novo_destino()
            proxima_pausa = randf_range(float(perfil.get("pausa_min", 4.0)), float(perfil.get("pausa_max", 15.0)))
    else:
        var plano := Vector3(position.x, 0.0, position.z)
        var para_destino := Vector3(destino.x - plano.x, 0.0, destino.z - plano.z)
        para_destino.y = 0.0
        if para_destino.length() < 1.2:
            if randf() < 0.5:
                estado = "pausado"
                tempo_pausa = randf_range(1.5, 5.0)
            else:
                destino = _novo_destino()
        else:
            var desejado := para_destino.normalized()
            direcao_atual = direcao_atual.lerp(desejado, minf(delta * 3.5, 1.0)).normalized()
            plano += direcao_atual * velocidade_alvo * delta
            position = Vector3(plano.x, position.y, plano.z)
        # Pausa ocasional no meio do trajeto, como gente real.
        proxima_pausa -= delta
        if proxima_pausa <= 0.0 and estado == "andando":
            estado = "pausado"
            tempo_pausa = randf_range(float(perfil.get("pausa_min", 3.0)), float(perfil.get("pausa_max", 10.0)))
            proxima_pausa = randf_range(15.0, 60.0)

    # Gravidade simples (mantém os pés no chão).
    vel_y -= GRAVIDADE * delta
    pos_y += vel_y * delta
    if pos_y < 0.0:
        pos_y = 0.0
        vel_y = 0.0
    raiz.position.y = 0.55 * (float(perfil.get("altura", 1.7)) / 1.70) + pos_y

    # Giro suave para a direção do movimento.
    var angulo_alvo: float = atan2(direcao_atual.x, direcao_atual.z)
    rotation.y = lerp_angle(rotation.y, angulo_alvo, minf(delta * 6.0, 1.0))

    _animar(delta)

func _animar(delta: float) -> void:
    var andando: bool = estado == "andando"
    var velocidade_efetiva: float = velocidade_alvo if andando else 0.0
    var h: float = float(perfil.get("altura", 1.70))
    var passada_m: float = PASSO_POR_ALTURA * h
    if clips.has("walk"):
        passada_m = float(clips["walk"]["stride"]) * (h / 1.70)
    if andando and passada_m > 0.1:
        fase_passada = fposmod(fase_passada + delta * velocidade_efetiva / passada_m, 1.0)
    var alvo_peso: float = 1.0 if andando else 0.0
    peso_movimento = lerpf(peso_movimento, alvo_peso, 1.0 - exp(-delta * 6.0))

    if clips.has("walk") and clips.has("idle"):
        _pose_da_amber(fase_passada, peso_movimento)
    else:
        _pose_basica(fase_passada, peso_movimento)

# Lê as curvas reais da Amber (cabeça, braços, pernas) aplicadas ao esqueleto simples.
# Convenção do bake: quadriceps = delta X do osso da coxa; joelho dobra com valor
# negativo de X aplicado em rotation.x do nó-joelho (o eixo Y inverte o sentido).
func _pose_da_amber(fase: float, peso: float) -> void:
    var clip: Dictionary = clips["walk"]
    var idle: Dictionary = clips["idle"]
    var dur: float = float(clip["duracao"])
    var t: float = fposmod(fase, 1.0) * dur
    var v := _ler_clip(clip, t)
    var i := _ler_clip(idle, t)
    # v[0]=pescoço v[1]=ombroE v[2]=ombroD v[3]=cotoveloE v[4]=cotoveloD
    # v[5]=coxaE v[6]=coxaD v[7]=canelaE v[8]=canelaD v[9]=peE v[10]=peD
    var cabeca_a: float = lerpf(i[0], v[0], peso)
    var omb_e: float = lerpf(i[1], v[1], peso)
    var omb_d: float = lerpf(i[2], v[2], peso)
    var cot_e: float = lerpf(i[3], v[3], peso)
    var cot_d: float = lerpf(i[4], v[4], peso)
    var cox_e: float = lerpf(i[5], v[5], peso)
    var cox_d: float = lerpf(i[6], v[6], peso)
    var can_e: float = lerpf(i[7], v[7], peso)
    var can_d: float = lerpf(i[8], v[8], peso)
    var pe_e: float = lerpf(i[9], v[9], peso)
    var pe_d: float = lerpf(i[10], v[10], peso)

    var repouso := _ler_clip(idle, t)
    cabeca.rotation.x = clampf(cabeca_a, -0.3, 0.3)
    # Delta em relação ao repouso do idle: os braços já pendem para baixo.
    ombro_e.rotation.x = clampf(omb_e - repouso[1], -1.0, 1.0)
    ombro_d.rotation.x = clampf(omb_d - repouso[2], -1.0, 1.0)
    # O bake traz o antebraço já flexionado (~+0.4..0.6 rad); no esqueleto
    # simples a dobra do cotovelo é rotation.x positivo para trás.
    cotovelo_e.rotation.x = clampf(cot_e, 0.0, 1.4)
    cotovelo_d.rotation.x = clampf(cot_d, 0.0, 1.4)
    quadril_e.rotation.x = clampf(-cox_e, -0.9, 0.9)
    quadril_d.rotation.x = clampf(-cox_d, -0.9, 0.9)
    joelho_e.rotation.x = clampf(can_e, 0.0, 1.5)
    joelho_d.rotation.x = clampf(can_d, 0.0, 1.5)
    tornozelo_e.rotation.x = clampf(pe_e, -0.5, 0.5)
    tornozelo_d.rotation.x = clampf(pe_d, -0.5, 0.5)

func _ler_clip(clip: Dictionary, t: float) -> Array[float]:
    var amostras: Array = clip["amostras"]
    var por: int = int(clip["por_quadro"])
    var n: int = amostras.size() / por
    var dur: float = float(clip["duracao"])
    var idx_f: float = fposmod(t, dur) * float(n - 1) / dur
    var a: int = int(floor(idx_f)) % maxi(n - 1, 1)
    var b: int = mini(a + 1, n - 1)
    var fr: float = idx_f - floor(idx_f)
    var saida: Array[float] = []
    for k in range(por):
        var va: float = amostras[a * por + k]
        var vb: float = amostras[b * por + k]
        saida.append(lerpf(va, vb, fr))
    return saida

# Fallback procedural caso o JSON não seja carregado.
func _pose_basica(fase: float, peso: float) -> void:
    var ang: float = fase * TAU
    quadril_e.rotation.x = sin(ang) * 0.5 * peso
    quadril_d.rotation.x = sin(ang + PI) * 0.5 * peso
    joelho_e.rotation.x = maxf(sin(ang) * 0.6, 0.0) * peso
    joelho_d.rotation.x = maxf(sin(ang + PI) * 0.6, 0.0) * peso
    ombro_e.rotation.x = sin(ang + PI) * 0.4 * peso
    ombro_d.rotation.x = sin(ang) * 0.4 * peso
    tornozelo_e.rotation.x = -sin(ang) * 0.25 * peso
    tornozelo_d.rotation.x = -sin(ang + PI) * 0.25 * peso
