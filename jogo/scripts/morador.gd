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

const IA := preload("res://scripts/ia_morador.gd")

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

# ---- Adereços: café na mão e cigarro (fuma parado, depois sai andando) ----
var adereco: String = ""            # "" | cafe | cigarro
var mao_cafe: String = "d"          # mão que segura o copo de café
var tempo_fumar: float = 0.0        # duração da pausa para fumar (s)
var fumando: bool = false           # true durante a pausa do cigarro
var braco_copo: Node3D = null       # antebraço com o copo (referência p/ pose)
var _braco_len: float = 0.30        # comprimento do braço (definido em _montar_corpo)
var _cabeca_r: float = 0.115        # raio da cabeça (definido em _montar_corpo)
var copo: MeshInstance3D = null
var cigarro_mesh: MeshInstance3D = null
var brasa: PointLight3D = null      # brasinha laranja que acende ao tragar
var fumaça: GPUParticles3D = null
var ponta_cigarro: Node3D = null    # nó na altura dos lábios p/ posicionar o cigarro
var ciclo_tragada: float = 0.0      # timer da tragada (~4 s por tragada)

# ---- IA emocional (dor, medo, raiva, falas rápidas) ----
var ia: RefCounted = null           # instância de scripts/ia_morador.gd
var local_ferimento: String = "toraco"   # toraco | coxaE | coxaD | bracoE | bracoD
var dor_pose: float = 0.0           # 0..1 peso da pose de segurar a ferida
var fugindo: bool = false
var velocidade_fuga: float = 3.2
var caido: bool = false
var angulo_caida: float = 0.0
var tempo_congelado: float = 0.0
var balao_texto: String = ""        # última fala escolhida pela IA
var sangue: GPUParticles3D = null
signal morador_atingido(morador: Node3D, dano: float, causador: Node3D)

func configurar(dados: Dictionary, inicial: Vector3, json_animacao: Variant = null) -> void:
    perfil = dados
    ia = IA.new(int(hash(String(dados.get("id", name)))))
    if dados.has("nome") and String(dados["nome"]) != "":
        ia.nome = String(dados["nome"])
    if json_animacao is Dictionary:
        _interpretar_clips(json_animacao)
    velocidade_alvo = float(dados.get("velocidade", 1.35))
    fase_passada = float(dados.get("fase", 0.0))
    position = inicial
    destino = _novo_destino()

func _ready() -> void:
    _carregar_clips()
    randomize()
    # Fumantes começam já com um cigarro aceso na mão (pose de fumar).
    if String(perfil.get("adereco", "")) == "cigarro" and randf() < 0.5:
        fumando = true
        estado = "pausado"
        tempo_fumar = randf_range(float(perfil.get("fumar_min", 30.0)), float(perfil.get("fumar_max", 120.0)))
    proxima_pausa = randf_range(float(perfil.get("pausa_min", 4.0)), float(perfil.get("pausa_max", 15.0)))
    # Corpo montado por último para que os adereços (café/cigarro) sejam presos
    # aos braços e à cabeça já existentes.
    _montar_corpo()
    _criar_aderecos()

# Cria os apetrechos conforme o perfil: copo de café ou cigarro com brasa/fumaça.
func _criar_aderecos() -> void:
    adereco = String(perfil.get("adereco", ""))
    if adereco == "":
        return
    var h: float = float(perfil.get("altura", 1.70))
    var escala: float = h / 1.70
    mao_cafe = String(perfil.get("segurando_mao", "d"))
    if adereco == "cafe":
        # Copo de papel preso à mão (antebraço) escolhida.
        braco_copo = cotovelo_d if mao_cafe == "d" else cotovelo_e
        var copo_mat := _mat(Color(0.92, 0.9, 0.86), 0.6)
        copo = _peca(braco_copo, Vector3(0, -_braco_len * 1.02, _braco_len * 0.45),
            Vector3(0.075 * escala, 0.13 * escala, 0.075 * escala), copo_mat, "CopoCafe")
        _peca(copo, Vector3(0, 0.075 * escala, 0),
            Vector3(0.085 * escala, 0.02 * escala, 0.085 * escala), _mat(Color(0.35, 0.2, 0.1), 0.5), "Tampa")
    elif adereco == "cigarro":
        # Ponto na altura dos lábios; cigarro aparece só quando ele para pra fumar.
        ponta_cigarro = _no(cabeca, Vector3(0.02 * escala, -_cabeca_r * 0.35, _cabeca_r * 0.95), "Boca")
        cigarro_mesh = _peca(ponta_cigarro, Vector3(0, 0, 0.03 * escala),
            Vector3(0.012 * escala, 0.012 * escala, 0.075 * escala), _mat(Color(0.95, 0.93, 0.85), 0.9), "Cigarro")
        cigarro_mesh.visible = false
        brasa = PointLight3D.new()
        brasa.name = "Brasa"
        brasa.light_color = Color(1.0, 0.35, 0.08)
        brasa.light_energy = 0.0
        brasa.omni_range = 0.35
        brasa.position = Vector3(0, 0, 0.07 * escala)
        ponta_cigarro.add_child(brasa)
        fumaça = GPUParticles3D.new()
        fumaça.name = "Fumaca"
        var proc := ParticleProcessMaterial.new()
        proc.direction = Vector3(0, 1, 0.15)
        proc.spread = 12.0
        proc.gravity = Vector3(0.05, 0.35, 0.0)
        proc.initial_velocity_min = 0.05
        proc.initial_velocity_max = 0.15
        proc.scale_amount_min = 0.012
        proc.scale_amount_max = 0.03
        proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
        proc.emission_sphere_radius = 0.01
        var grad := Gradient.new()
        grad.set_color(0, Color(0.85, 0.85, 0.88, 0.35))
        grad.set_color(1, Color(0.9, 0.9, 0.92, 0.0))
        proc.color_ramp = grad
        fumaça.process_material = proc
        fumaça.amount = 24
        fumaça.lifetime = 2.2
        fumaça.preprocess = 0.5
        fumaça.visible = false
        var quad := QuadMesh.new()
        quad.size = Vector2(0.06, 0.06)
        var smoke_mat := StandardMaterial3D.new()
        smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        smoke_mat.vertex_color_use_as_albedo = true
        smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
        smoke_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
        quad.material = smoke_mat
        fumaça.draw_pass_1 = quad
        ponta_cigarro.add_child(fumaça)

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
    _braco_len = braco
    var perna_sup: float = 0.42 * escala
    var perna_inf: float = 0.42 * escala
    var pescoco: float = 0.10 * escala
    var cabeca_r: float = 0.115 * escala
    _cabeca_r = cabeca_r
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
    # ---- IA emocional roda sempre (mesmo parada): decide falas e estado ----
    if ia != null:
        ia.pensar(delta)
        var fala: String = ia.proxima_fala(delta)
        if fala != "":
            balao_texto = fala
        else:
            balao_texto = ""
        # Contágio de pânico: medo alto faz essa pessoa fugir (dor forte fica
        # no lugar segurando a ferida).
        if not fugindo and not caido and ia.deve_fugir() and ia.dor < 0.75:
            _comecar_fuga()
    if caido:
        # Termina a queda e congela o corpo no chão.
        _animar_caida(delta)
        tempo_congelado += delta
        if tempo_congelado > 1.2:
            set_physics_process(false)
        return
    if estado == "pausado":
        tempo_pausa -= delta
        if fumando:
            # Ciclo de tragadas: brasa acende a cada ~4 s e fumaça sobe.
            ciclo_tragada += delta
            if ciclo_tragada > 4.0:
                ciclo_tragada = 0.0
        if tempo_pausa <= 0.0:
            if fumando:
                _terminar_cigarro()   # apaga, joga o cigarro fora e sai andando
            # Quem ainda está com muita dor continua segurando a ferida;
            # quando a dor passa, volta a vagar normalmente.
            if ia != null and ia.dor > 0.25:
                tempo_pausa = 4.0
            else:
                estado = "andando"
                destino = _novo_destino()
                proxima_pausa = randf_range(float(perfil.get("pausa_min", 4.0)), float(perfil.get("pausa_max", 15.0)))
    else:
        var plano := Vector3(position.x, 0.0, position.z)
        # Quem está fugindo corre na direção OPOSTA ao agressor/última origem.
        if fugindo and ia != null and ia.ultimo_atirador != null and is_instance_valid(ia.ultimo_atirador):
            var ameaca: Vector3 = (ia.ultimo_atirador as Node3D).global_position
            destino = Vector3(position.x + (position.x - ameaca.x), 0.0, position.z + (position.z - ameaca.z))
            destino.x = clampf(destino.x, -MARGEM, MARGEM)
            destino.z = clampf(destino.z, -MARGEM, MARGEM)
        var para_destino := Vector3(destino.x - plano.x, 0.0, destino.z - plano.z)
        para_destino.y = 0.0
        var vel_atual: float = velocidade_fuga if fugindo else velocidade_alvo
        if para_destino.length() < 1.2:
            if fugindo:
                _parar_de_fugir()
            elif randf() < 0.5:
                estado = "pausado"
                tempo_pausa = randf_range(1.5, 5.0)
            else:
                destino = _novo_destino()
        else:
            var desejado := para_destino.normalized()
            direcao_atual = direcao_atual.lerp(desejado, minf(delta * 3.5, 1.0)).normalized()
            plano += direcao_atual * vel_atual * delta
            position = Vector3(plano.x, position.y, plano.z)
        # Pausa ocasional no meio do trajeto, como gente real.
        # Fumantes que pausam aproveitam pra acender um cigarro e fumar parado
        # por um bom tempo (fumar_min..fumar_max), depois saem andando com o
        # cigarro já jogado fora.
        proxima_pausa -= delta
        if proxima_pausa <= 0.0 and estado == "andando" and not fugindo:
            if adereco == "cigarro" and not fumando:
                _acender_cigarro()
            else:
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
    _process_aderecos(delta)

# ============ DANO / DOR (chamado pelo sistema de armas) ============
## O morador é atingido: a IA emocional decide na hora o que gritar, ele para
## tudo, coloca a mão no lugar ferido e curva o corpo de dor. Se a vida zerar,
## desaba no chão.
func receber_dano(dano: float, causador: Node3D, corpo_a_corpo: bool = false) -> void:
    if ia == null or caido:
        return
    # Local do ferimento sorteado (toraco/coxas/braços) p/ a mão ir exatamente lá.
    var opcoes: Array[String] = ["toraco", "toraco", "coxaE", "coxaD", "bracoE", "bracoD"]
    local_ferimento = opcoes[randi() % opcoes.size()]
    ia.ser_atingido(dano, causador, corpo_a_corpo)
    fumando = false
    _terminar_cigarro()
    fugindo = false
    estado = "pausado"
    tempo_pausa = 9999.0            # fica segurando a dor até a IA decidir
    dor_pose = 1.0
    _criar_sangue()
    morador_atingido.emit(self, dano, causador)
    if ia.morto:
        _desabar()

# Pose de dor: braço vai até o local ferido, ombro encolhe, cabeça baixa e
# joelhos flexionam levemente (curvado sobre a própria dor).
func _pose_dor() -> void:
    if raiz == null:
        return
    var alvo_local: Vector3 = Vector3(0, 0.2, 0.16)   # padrão: meio do peito
    match local_ferimento:
        "coxaE": alvo_local = Vector3(-0.12, -0.55, 0.12)
        "coxaD": alvo_local = Vector3(0.12, -0.55, 0.12)
        "bracoE": alvo_local = Vector3(-0.42, -0.05, 0.1)
        "bracoD": alvo_local = Vector3(0.42, -0.05, 0.1)
    var braco_usar: Node3D = ombro_e
    var ante_usar: Node3D = cotovelo_e
    if alvo_local.x > 0.0:
        braco_usar = ombro_d
        ante_usar = cotovelo_d
    else:
        braco_usar = ombro_e
        ante_usar = cotovelo_e
    # Ombro fecha sobre a ferida; antebraço sobe até o ponto dolorido.
    braco_usar.rotation.x = lerpf(braco_usar.rotation.x, -1.15, 0.25)
    braco_usar.rotation.z = lerpf(braco_usar.rotation.z, signf(alvo_local.x) * -0.7, 0.25)
    ante_usar.rotation.x = lerpf(ante_usar.rotation.x, -1.35, 0.25)
    # O outro braço também sobe em proteção instintiva.
    var outro := cotovelo_d if braco_usar == cotovelo_e else cotovelo_e
    outro.rotation.x = lerpf(outro.rotation.x, -0.8, 0.2)
    # Corpo curvado: quadril e cabeça pendem para frente, pernas cedem.
    toraco.rotation.x = lerpf(toraco.rotation.x, 0.5, 0.15)
    cabeca.rotation.x = lerpf(cabeca.rotation.x, 0.55, 0.15)
    quadril_e.rotation.x = lerpf(quadril_e.rotation.x, 0.25, 0.2)
    quadril_d.rotation.x = lerpf(quadril_d.rotation.x, 0.25, 0.2)
    joelho_e.rotation.x = lerpf(joelho_e.rotation.x, 0.35, 0.2)
    joelho_d.rotation.x = lerpf(joelho_d.rotation.x, 0.35, 0.2)

func _desabar() -> void:
    caido = true
    estado = "parado"
    fugindo = false
    dor_pose = 0.0
    if sangue != null:
        sangue.emitting = true

func _animar_caida(delta: float) -> void:
    # Desaba de costas/joelhos e fica imóvel.
    angulo_caida = lerpf(angulo_caida, PI * 0.5 * 0.92, minf(delta * 5.0, 1.0))
    if raiz != null:
        raiz.rotation.x = -angulo_caida
        var h: float = float(perfil.get("altura", 1.7)) / 1.70
        raiz.position.y = lerpf(raiz.position.y, 0.28 * h, minf(delta * 5.0, 1.0))

func _comecar_fuga() -> void:
    if fugindo or caido:
        return
    fugindo = true
    estado = "andando"
    fumando = false
    _terminar_cigarro()
    destino = position + direcao_atual * -10.0

func _parar_de_fugir() -> void:
    fugindo = false
    if ia != null:
        ia.medo = maxf(0.0, ia.medo - 0.4)
    destino = _novo_destino()

# Partículas de sangue simples no ponto do ferimento (barato p/ Android).
func _criar_sangue() -> void:
    if sangue != null:
        sangue.visible = true
        sangue.emitting = true
        return
    sangue = GPUParticles3D.new()
    sangue.name = "Sangue"
    var proc := ParticleProcessMaterial.new()
    proc.direction = Vector3(0, 0.6, 0.3)
    proc.spread = 45.0
    proc.gravity = Vector3(0, -9.0, 0)
    proc.initial_velocity_min = 0.4
    proc.initial_velocity_max = 1.1
    proc.scale_amount_min = 0.015
    proc.scale_amount_max = 0.035
    var grad := Gradient.new()
    grad.set_color(0, Color(0.55, 0.03, 0.03, 0.9))
    grad.set_color(1, Color(0.35, 0.02, 0.02, 0.0))
    proc.color_ramp = grad
    sangue.process_material = proc
    sangue.amount = 40
    sangue.lifetime = 1.2
    sangue.one_shot = true
    sangue.emitting = true
    var quad := QuadMesh.new()
    quad.size = Vector2(0.035, 0.035)
    var mat := StandardMaterial3D.new()
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.vertex_color_use_as_albedo = true
    mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    quad.material = mat
    sangue.draw_pass_1 = quad
    sangue.position = Vector3(0, 0.2, 0.18)
    toraco.add_child(sangue)

# ---- Ciclo do cigarro: acender (para fumar parado) e apagar/jogar fora ----
func _acender_cigarro() -> void:
    fumando = true
    estado = "pausado"
    tempo_fumar = randf_range(float(perfil.get("fumar_min", 30.0)), float(perfil.get("fumar_max", 120.0)))
    tempo_pausa = tempo_fumar
    ciclo_tragada = randf_range(0.0, 4.0)
    if fumaça != null:
        fumaça.visible = true
        fumaça.emitting = true

func _terminar_cigarro() -> void:
    fumando = false
    # Ele "joga o cigarro fora": cigarro e fumaça somem e ele sai andando.
    if cigarro_mesh != null:
        cigarro_mesh.visible = false
    if brasa != null:
        brasa.light_energy = 0.0
    if fumaça != null:
        fumaça.emitting = false
        fumaça.visible = false

# Brasa e fumaça acompanham as tragadas enquanto ele fuma parado.
func _process_aderecos(delta: float) -> void:
    if adereco == "cigarro" and fumando and ponta_cigarro != null:
        var t: float = fposmod(ciclo_tragada, 4.0) / 4.0
        var intensidade: float = maxf(0.0, sin(t * PI))
        brasa.light_energy = lerpf(brasa.light_energy, 0.9 * intensidade, minf(delta * 8.0, 1.0))
        fumaça.emitting = intensidade > 0.15

# ---- API usada pelo sistema de armas do jogador ----
## Aplica dano vindo do jogador (tiros/facadas). A IA emocional reage na hora:
## grita, escolhe a frase e o corpo vai à pose de segurar a ferida.
func aplicar_dano(dano: float, origem: Vector3, agressor: Node3D, corpo_a_corpo: bool = false) -> void:
    receber_dano(dano, agressor, corpo_a_corpo)
    # Pânico contágio: moradores próximos ao tiro também se assustam.
    var pai := get_parent()
    if pai != null and pai.has_method("alarme_tiro"):
        pai.alarme_tiro(global_position, self)

## Grito de dor imediato usado no feedback instantâneo da arma.
func gritar_dor() -> String:
    if ia == null:
        return "AAAAI!"
    var pool: Array[String] = ia.GRITO_DOR
    return pool[randi() % pool.size()]

## Chamado quando alguém leva tiro por perto: entra em pânico e sai correndo.
func susto_pertissimo() -> void:
    if ia == null or caido or fugindo or estado == "dor":
        return
    ia.entrar_em_panico(global_position)
    _comecar_fuga()
    destino = _destino_fuga()

func _destino_fuga() -> Vector3:
    var p := position
    for i in range(8):
        var alvo := _novo_destino()
        if alvo.distance_to(p) > 60.0:
            return alvo
    return p + Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)).normalized() * 120.0

func _animar(delta: float) -> void:
    var andando: bool = estado == "andando"
    var velocidade_efetiva: float = (velocidade_fuga if fugindo else velocidade_alvo) if andando else 0.0
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
    # Segurando a ferida: a pose de dor por cima da animação base.
    if dor_pose > 0.05 and not caido:
        _pose_dor()
        dor_pose = lerpf(dor_pose, 0.0 if ia == null or ia.dor < 0.25 else 1.0, 1.0 - exp(-delta * 2.0))
    _pose_aderecos()
    _atualizar_balao(delta)

# Balão de fala desenhado em runtime (Label3D): mostra MUITO RÁPIDO a frase
# que a IA emocional escolheu ao levar tiro/facada.
var _balao: Label3D = null
func _atualizar_balao(_delta: float) -> void:
    if balao_texto == "" and (_balao == null or not _balao.visible):
        return
    if _balao == null:
        _balao = Label3D.new()
        _balao.name = "BalaoFala"
        _balao.position = Vector3(0, 2.05 * (float(perfil.get("altura", 1.7)) / 1.70), 0)
        _balao.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        _balao.no_depth_test = true
        _balao.font_size = 44
        _balao.outline_size = 10
        _balao.modulate = Color(1, 1, 1, 1)
        _balao.background_modulate = Color(0.08, 0.08, 0.1, 0.82)
        cabeca.add_child(_balao)
    _balao.text = balao_texto
    _balao.visible = balao_texto != ""

# Pose dos adereços sobre a pose base: braço do café dobrado à frente (segurando
# o copo) e, enquanto fuma, o braço direito vai e volta da boca em tragadas.
func _pose_aderecos() -> void:
    # Com dor, as mãos vão para a ferida (prioridade sobre café/cigarro).
    if dor_pose > 0.35 or fugindo:
        return
    if adereco == "cafe":
        var ombro_cafe: Node3D = ombro_d if mao_cafe == "d" else ombro_e
        var cot_cafe: Node3D = cotovelo_d if mao_cafe == "d" else cotovelo_e
        # Antebraço dobrado ~90° à frente, na altura da cintura, segurando o copo.
        cot_cafe.rotation.x = -1.5
        ombro_cafe.rotation.x = lerpf(ombro_cafe.rotation.x, -0.25, 0.4)
    elif adereco == "cigarro" and fumando:
        # Tragada: mão sobe até a boca no pico do ciclo (~4 s por tragada).
        var t: float = fposmod(ciclo_tragada, 4.0) / 4.0
        var subir: float = maxf(0.0, sin(t * PI))
        # Ombro pende levemente para frente e o antebraço dobra em direção à boca.
        ombro_d.rotation.x = lerpf(clampf(ombro_d.rotation.x, -0.6, 0.6), -0.35, subir)
        cotovelo_d.rotation.x = lerpf(clampf(cotovelo_d.rotation.x, -1.6, 0.0), -1.75, subir)
        cigarro_mesh.visible = true
    elif adereco == "cigarro":
        cigarro_mesh.visible = false

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
