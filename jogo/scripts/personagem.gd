extends CharacterBody3D
## Amber: controles de toque e teclado, gravidade, pulo e movimento relativo a camera.
## Tambem aplica pequenos ajustes visuais para deixar a personagem menos "plastica"
## e melhor integrada ao chao sem pesar demais no Android.
@export var velocidade: float = 1.65
@export var impulso_pulo: float = 6.2
@export var gravidade: float = 18.0
@onready var visual: Node3D = get_node_or_null("Modelo_Amber") as Node3D
@onready var camera: Camera3D = get_node_or_null("../Camera3D") as Camera3D
var acoes: Dictionary = {"frente": false, "tras": false, "esquerda": false, "direita": false, "pular": false}
var pulo_anterior: bool = false
var analogico: Vector2 = Vector2.ZERO
var controles_ativos: bool = true
var _cache_texturas: Dictionary = {}
var _sombra: MeshInstance3D = null
var _material_sombra: StandardMaterial3D = null
var _anim_player: AnimationPlayer = null
var _nomes_animacao: Dictionary = {}
var _anim_atual: String = ""
var _pulo_ativo: bool = false
var _correr: bool = false
var _escala_visual_base: Vector3 = Vector3.ONE
var _luz_rosto: OmniLight3D = null
var _luz_rim: OmniLight3D = null

func _ready() -> void:
    # A cena principal pode carregar sem o GLB se a importacao do Android falhou.
    # Tente instanciar o MESMO modelo original; nunca crie um boneco substituto.
    if visual == null:
        var modelo: Resource = load("res://assets/Amber_animada.glb")
        if modelo is PackedScene:
            var instancia: Node = (modelo as PackedScene).instantiate()
            if instancia is Node3D:
                visual = instancia as Node3D
                visual.name = "Modelo_Amber"
                visual.rotation = Vector3(0.0, PI, 0.0)
                visual.scale = Vector3.ONE * 0.9451397
                add_child(visual)
                print("AmberCity: modelo original recuperado por carregamento direto.")
    if visual == null:
        push_error("AmberCity: importacao de assets/Amber_animada.glb falhou. Aguarde a importacao no editor Godot; veja a aba Saida/Erros.")
        return
    _escala_visual_base = visual.scale
    _melhorar_visual_amber()
    # O no Animacao_Confiavel controla os ossos diretamente, sem AnimationPlayer.

func definir_analogico(valor: Vector2) -> void:
    analogico = valor.limit_length(1.0)

func definir_controles_ativos(ativos: bool) -> void:
    controles_ativos = ativos
    if not ativos:
        analogico = Vector2.ZERO
        acoes["pular"] = false
        pulo_anterior = false
        velocity.x = 0.0
        velocity.z = 0.0

func definir_acao(acao: String, pressionado: bool) -> void:
    if acoes.has(acao):
        acoes[acao] = pressionado

func _physics_process(delta: float) -> void:
    if visual == null:
        return  # Nao acessar malha inexistente se a importacao do GLB falhou.
    var eixo_x: float = analogico.x + float(int(acoes["direita"]) - int(acoes["esquerda"]))
    var eixo_z: float = analogico.y + float(int(acoes["frente"]) - int(acoes["tras"]))
    if controles_ativos and (Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)):
        eixo_x += 1.0
    if controles_ativos and (Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)):
        eixo_x -= 1.0
    if controles_ativos and (Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)):
        eixo_z += 1.0
    if controles_ativos and (Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)):
        eixo_z -= 1.0

    var frente: Vector3 = Vector3.FORWARD
    var direita: Vector3 = Vector3.RIGHT
    if camera != null:
        frente = -camera.global_basis.z
        frente.y = 0.0
        frente = frente.normalized()
        direita = camera.global_basis.x
        direita.y = 0.0
        direita = direita.normalized()
    # Preserva a intensidade do analogico; teclado continua com velocidade total.
    var entrada: Vector2 = Vector2(eixo_x, eixo_z).limit_length(1.0) if controles_ativos else Vector2.ZERO
    var direcao: Vector3 = direita * entrada.x + frente * entrada.y
    # Deslocamento e movimento das pernas usam a mesma intensidade.
    # No celular, empurre o analogico ate o fim para correr; no teclado, Shift.
    # Histerese evita que a animacao corra/ande pisque quando o dedo treme
    # perto do limite do analogico do Android.
    if not controles_ativos:
        _correr = false
    elif Input.is_key_pressed(KEY_SHIFT):
        _correr = true
    elif analogico.length() > 0.97:
        _correr = true
    elif analogico.length() < 0.85:
        _correr = false
    # Passadas calculadas no esqueleto: caminhar ~1,65 m/s, correr ~2,75 m/s.
    # Mantem a distancia percorrida perto da passada dos pes.
    var velocidade_atual: float = velocidade * (1.67 if _correr else 1.0)
    var velocidade_desejada: Vector3 = direcao * velocidade_atual
    var aceleracao: float = 12.0 if direcao.length_squared() > 0.0001 else 16.0
    velocity.x = move_toward(velocity.x, velocidade_desejada.x, aceleracao * delta)
    velocity.z = move_toward(velocity.z, velocidade_desejada.z, aceleracao * delta)
    if not is_on_floor():
        velocity.y -= gravidade * delta
    elif velocity.y < 0.0:
        velocity.y = -0.1
    var pular: bool = controles_ativos and (bool(acoes["pular"]) or Input.is_key_pressed(KEY_SPACE))
    if is_on_floor() and pular and not pulo_anterior:
        velocity.y = impulso_pulo
        _pulo_ativo = true
    pulo_anterior = pular
    move_and_slide()
    if is_on_floor():
        _pulo_ativo = false
    # Usa deslocamento REAL apos colisao, nao so entrada do analogico.
    # Assim os pes param de caminhar quando Amber encontra uma parede.
    var velocidade_real: float = Vector2(get_real_velocity().x, get_real_velocity().z).length()
    # Animacao_Confiavel usa get_real_velocity() e ajusta ossos no seu _physics_process.
    _atualizar_sombra(delta)
    # Respiracao muito discreta; nao move os pes para baixo do chao.
    var ar: float = sin(Time.get_ticks_msec() * 0.0018)
    visual.scale.y = _escala_visual_base.y * (1.0 + 0.003 * ar)
    if direcao.length_squared() > 0.01:
        visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direcao.x, direcao.z), minf(delta * 10.0, 1.0))
    if global_position.y < -15.0:
        global_position = Vector3(0.0, 0.02, 7.0)
        velocity = Vector3.ZERO
        _pulo_ativo = false

func _buscar_animation_player(no: Node) -> AnimationPlayer:
    if no is AnimationPlayer:
        return no as AnimationPlayer
    for filho in no.get_children():
        var resultado := _buscar_animation_player(filho)
        if resultado != null:
            return resultado
    return null

func _iniciar_animacoes() -> void:
    _anim_player = _buscar_animation_player(visual)
    if _anim_player == null:
        push_warning("Amber: GLB animado importado sem AnimationPlayer. Confira o arquivo Amber_animada.glb.")
        return
    for nome in _anim_player.get_animation_list():
        var ultimo: String = str(nome).get_slice("/", str(nome).get_slice_count("/") - 1)
        var chave: String = ultimo.to_lower()
        if chave in ["idle", "walk", "run", "jump"]:
            _nomes_animacao[chave] = str(nome)
            var anim: Animation = _anim_player.get_animation(nome)
            if anim != null:
                anim.loop_mode = Animation.LOOP_NONE if chave == "jump" else Animation.LOOP_LINEAR
    if not _nomes_animacao.has("idle"):
        push_warning("Amber: nao foi encontrada a animacao Idle. Disponiveis: %s" % str(_anim_player.get_animation_list()))
    _trocar_animacao("idle", 0.0)

func _trocar_animacao(nome: String, transicao: float = 0.14) -> void:
    if _anim_player == null or _anim_atual == nome or not _nomes_animacao.has(nome):
        return
    _anim_atual = nome
    _anim_player.play(_nomes_animacao[nome], transicao)

func _atualizar_animacao(velocidade_real: float) -> void:
    if _anim_player == null:
        return
    if _pulo_ativo or not is_on_floor():
        _trocar_animacao("jump", 0.08)
    elif velocidade_real < 0.12 or not controles_ativos:
        _trocar_animacao("idle", 0.20)
    elif _correr:
        _trocar_animacao("run", 0.13)
    else:
        _trocar_animacao("walk", 0.16)
    # Cadencia proporcional a velocidade atingida de fato. O GLB contem
    # ciclos de caminhada de 1 s e corrida de 0,67 s, portanto tocamos
    # cada um a 1x em suas velocidades nominais de 1,65 e 2,75 m/s.
    # A versao antiga usava 2,2x e 1,8x e acelerava artificialmente os pes.
    if _anim_atual == "walk":
        _anim_player.speed_scale = clampf(velocidade_real / velocidade, 0.15, 1.25)
    elif _anim_atual == "run":
        _anim_player.speed_scale = clampf(velocidade_real / (velocidade * 1.67), 0.15, 1.25)
    else:
        _anim_player.speed_scale = 1.0

func _melhorar_visual_amber() -> void:
    if visual == null:
        return
    _aplicar_sombra_contato()
    _aplicar_luz_suave_no_rosto()
    _configurar_malhas_recursivo(visual)

func _aplicar_luz_suave_no_rosto() -> void:
    if has_node("LuzRosto"):
        _luz_rosto = get_node("LuzRosto") as OmniLight3D
    else:
        var luz := OmniLight3D.new()
        luz.name = "LuzRosto"
        luz.position = Vector3(0.0, 1.60, 0.64)
        luz.light_color = Color(1.0, 0.96, 0.94, 1.0)
        luz.light_energy = 0.52
        luz.omni_range = 3.8
        luz.shadow_enabled = false
        luz.distance_fade_enabled = true
        luz.distance_fade_begin = 2.25
        luz.distance_fade_length = 1.35
        add_child(luz)
        _luz_rosto = luz
    if has_node("LuzRim"):
        _luz_rim = get_node("LuzRim") as OmniLight3D
    else:
        var rim := OmniLight3D.new()
        rim.name = "LuzRim"
        rim.position = Vector3(-0.26, 1.67, -0.42)
        rim.light_color = Color(0.95, 0.92, 0.90, 1.0)
        rim.light_energy = 0.20
        rim.omni_range = 3.1
        rim.shadow_enabled = false
        rim.distance_fade_enabled = true
        rim.distance_fade_begin = 1.9
        rim.distance_fade_length = 1.2
        add_child(rim)
        _luz_rim = rim

func _aplicar_sombra_contato() -> void:
    if has_node("SombraContato"):
        return
    var sombra := MeshInstance3D.new()
    sombra.name = "SombraContato"
    var plano := QuadMesh.new()
    plano.size = Vector2(0.95, 0.70)
    sombra.mesh = plano
    sombra.position = Vector3(0.0, 0.03, 0.02)
    sombra.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
    sombra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.no_depth_test = false
    mat.albedo_color = Color(1, 1, 1, 0.55)
    var tex := _carregar_textura("res://assets/amber_texturas/amber_shadow.png")
    if tex != null:
        mat.albedo_texture = tex
    sombra.material_override = mat
    add_child(sombra)
    # Uma sombra e uma projecao no mundo, nao parte do corpo que pula.
    sombra.top_level = true
    _sombra = sombra
    _material_sombra = mat
    _sombra.visible = false  # Primeiro raycast so no _physics_process, com mundo fisico pronto.

func _atualizar_sombra(delta: float) -> void:
    if _sombra == null or _material_sombra == null:
        return
    var inicio: Vector3 = global_position + Vector3.UP * 0.60
    var fim: Vector3 = global_position + Vector3.DOWN * 5.0
    var consulta := PhysicsRayQueryParameters3D.create(inicio, fim)
    consulta.collision_mask = 1
    consulta.exclude = [get_rid()]
    var contato: Dictionary = get_world_3d().direct_space_state.intersect_ray(consulta)
    if contato.is_empty():
        _sombra.visible = false
        return
    _sombra.visible = true
    var posicao: Vector3 = contato["position"]
    var distancia: float = maxf(0.0, global_position.y - posicao.y)
    var tamanho: float = 1.0 + minf(distancia * 0.18, 0.45)
    _sombra.scale = Vector3(tamanho, tamanho, tamanho)
    var alvo: Vector3 = posicao + Vector3.UP * 0.023
    # O sombreamento segue o piso mesmo durante um salto.
    _sombra.global_position = alvo if delta <= 0.0 else _sombra.global_position.lerp(alvo, minf(1.0, delta * 18.0))
    _sombra.global_rotation = Vector3(-PI * 0.5, 0.0, 0.0)
    var cor: Color = _material_sombra.albedo_color
    cor.a = 0.64 * (1.0 - clampf(distancia / 4.0, 0.0, 0.9))
    _material_sombra.albedo_color = cor

func _configurar_malhas_recursivo(no: Node) -> void:
    if no is MeshInstance3D:
        _configurar_mesh_instance(no as MeshInstance3D)
    for filho in no.get_children():
        _configurar_malhas_recursivo(filho)

func _configurar_mesh_instance(mesh_instance: MeshInstance3D) -> void:
    mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    if mesh_instance.mesh == null:
        return
    for superficie in range(mesh_instance.mesh.get_surface_count()):
        var material_base: Material = mesh_instance.get_active_material(superficie)
        if material_base == null:
            material_base = mesh_instance.mesh.surface_get_material(superficie)
        var nome_material := ""
        var material_novo: StandardMaterial3D
        if material_base is StandardMaterial3D:
            material_novo = (material_base as StandardMaterial3D).duplicate()
            nome_material = material_novo.resource_name
        else:
            material_novo = StandardMaterial3D.new()
            if material_base != null:
                nome_material = material_base.resource_name
        nome_material = _nome_material_original(mesh_instance, superficie, nome_material)
        material_novo.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
        _configurar_material_por_nome(material_novo, nome_material)
        # Corrige os olhos pela malha e indice: nao depende do nome do material
        # importado pelo Godot, que pode estar vazio ou ter sufixos.
        var nome_malha := (str(mesh_instance.name) + " " + str(mesh_instance.mesh.resource_name)).to_lower()
        var material_lower := nome_material.to_lower()
        if nome_malha.contains("eyeocclusion") or material_lower.contains("eye_occlusion"):
            _remover_camada_olho(material_novo)
        elif nome_malha.contains("cc_base_eye") or material_lower.contains("cornea") or material_lower.contains("std_eye_"):
            if superficie == 1 or superficie == 3 or material_lower.contains("cornea"):
                _remover_camada_olho(material_novo)
            elif superficie == 0 or superficie == 2 or material_lower.contains("std_eye_"):
                _corrigir_superficie_olho(material_novo, superficie)
        mesh_instance.set_surface_override_material(superficie, material_novo)

func _remover_camada_olho(mat: StandardMaterial3D) -> void:
    # Na fonte, a cornea continha outra copia da textura completa do olho.
    # Esta camada tambem podia cobrir a iris: nao renderizar a sobreposicao.
    mat.albedo_texture = null
    mat.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.normal_enabled = false
    mat.roughness_texture = null
    mat.metallic = 0.0

func _corrigir_superficie_olho(mat: StandardMaterial3D, superficie: int) -> void:
    var nome_arquivo := "olho_direito_corrigido.png" if superficie == 0 else "olho_esquerdo_corrigido.png"
    var textura := _carregar_textura("res://assets/amber_texturas/" + nome_arquivo)
    if textura == null:
        return
    mat.albedo_texture = textura
    mat.albedo_color = Color.WHITE
    mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
    mat.roughness = 0.28
    mat.roughness_texture = null
    mat.normal_enabled = false
    mat.metallic = 0.0

func _nome_material_original(malha: MeshInstance3D, indice: int, nome: String) -> String:
    var n: String = (str(malha.name) + " " + str(malha.mesh.resource_name)).to_lower()
    # A malha do GLB preserva a ordem das superficies. Os 4 cabelos tinham
    # todos o mesmo nome de material no GLB, mas TEXTURAS DIFERENTES.
    if n.contains("cc_base_body"):
        var pele := ["Std_Skin_Head", "Std_Skin_Body", "Std_Skin_Arm", "Std_Skin_Leg", "Std_Nails", "Std_Eyelash"]
        if indice < pele.size():
            return pele[indice]
    if n.contains("hair_base"):
        return "Hair_Transparency" if indice == 0 else "Scalp_Transparency"
    if n.contains("real_hair"):
        return "Hair_Transparency_0002"
    if n.contains("bun"):
        return "Hair_Transparency_0001"
    if n.contains("bang"):
        return "Hair_Transparency_0003"
    if n.contains("camila_brow"):
        return "Female_Brow_Transparency" if indice == 0 else "Female_Brow_Base_Transparency"
    if n.contains("punk_leather"):
        return "Punk_Leather_jacket"
    if n.contains("crop_t_shirt"):
        return "Female_T_Shirt"
    if n.contains("cc_base_eyeocclusion"):
        return "Std_Eye_Occlusion_R" if indice == 0 else "Std_Eye_Occlusion_L"
    if n.contains("cc_base_eye"):
        var olhos := ["Std_Eye_R", "Std_Cornea_R", "Std_Eye_L", "Std_Cornea_L"]
        if indice < olhos.size():
            return olhos[indice]
    return nome

func _configurar_material_por_nome(mat: StandardMaterial3D, nome_material: String) -> void:
    var nome: String = nome_material.to_lower()
    mat.metallic = 0.0
    # Original FBX: pele 2K (rosto), 1K (corpo). Normal REAL 2K/1K.
    if nome == "std_skin_head":
        mat.roughness = 0.54
        mat.albedo_color = Color(1.0, 0.985, 0.975, 1.0)
        mat.roughness_texture = null
        mat.normal_enabled = false
        _aplicar_mapas_originais(mat, nome_material, 0.09)
    elif nome.contains("skin"):
        mat.roughness = 0.62
        mat.albedo_color = Color(1.0, 0.990, 0.984, 1.0)
        mat.roughness_texture = null
        mat.normal_enabled = false
        _aplicar_mapas_originais(mat, nome_material, 0.12)
    elif nome.contains("nails"):
        mat.roughness = 0.48
    elif nome == "female_brow_transparency":
        # A camada extra de fios era projetada como tufos sobre os olhos.
        # A sobrancelha BASE continua visivel abaixo, sem duplicacao.
        mat.albedo_texture = null
        mat.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        mat.normal_enabled = false
    elif nome.contains("hair") or nome.contains("scalp") or nome.contains("eyelash") or nome.contains("brow"):
        _aplicar_corte_de_cabelo(mat, nome_material)
    elif nome.contains("jacket"):
        mat.roughness = 0.36
        _aplicar_mapas_originais(mat, nome_material, 0.42)
    elif nome.contains("jeans"):
        mat.roughness = 0.87
        _aplicar_mapas_originais(mat, nome_material, 0.55)
    elif nome.contains("boots"):
        mat.roughness = 0.47
        _aplicar_mapas_originais(mat, nome_material, 0.45)
    elif nome.contains("shirt") or nome.contains("bra") or nome.contains("underwear"):
        mat.roughness = 0.89
        _aplicar_mapas_originais(mat, nome_material, 0.48)
    elif nome.contains("eye_occlusion") or nome.contains("cornea"):
        _remover_camada_olho(mat)
    elif nome.contains("eye"):
        mat.roughness = 0.52
    elif nome.contains("teeth") or nome.contains("tongue"):
        mat.roughness = 0.59
    else:
        mat.roughness = 0.76

func _aplicar_mapas_originais(mat: StandardMaterial3D, nome_material: String, intensidade: float) -> void:
    var prefixo: String = "res://assets/amber_origem/" + nome_material
    var prefixo_refino_max: String = "res://assets/amber_visual_refino_max/" + nome_material
    var prefixo_refino: String = "res://assets/amber_visual_refino/" + nome_material
    var cor := _carregar_textura_multi([
        prefixo_refino_max + "_Diffuse.jpg", prefixo_refino_max + "_Diffuse.png",
        prefixo_refino + "_Diffuse.jpg", prefixo_refino + "_Diffuse.png",
        prefixo + "_Diffuse.jpg", prefixo + "_Diffuse.png"
    ])
    if cor != null:
        mat.albedo_texture = cor
    var normal := _carregar_textura_multi([prefixo_refino_max + "_Normal.png", prefixo_refino + "_Normal.png", prefixo + "_Normal.png"])
    if normal != null:
        mat.normal_enabled = true
        mat.normal_texture = normal
        mat.normal_scale = intensidade
    # Nao usa mapas de rugosidade inventados a partir de cor.
    mat.roughness_texture = null

func _aplicar_corte_de_cabelo(mat: StandardMaterial3D, nome_material: String) -> void:
    var arquivo: String = nome_material + "_Diffuse_cutout.png"
    if nome_material.begins_with("Hair_Transparency_"):
        arquivo = "Hair_Transparency_Diffuse_" + nome_material.trim_prefix("Hair_Transparency_") + "_cutout.png"
    var textura := _carregar_textura_multi([
        "res://assets/amber_visual_refino_max/" + arquivo,
        "res://assets/amber_visual_refino/" + arquivo,
        "res://assets/amber_origem/" + arquivo
    ])
    if textura == null:
        return
    mat.albedo_texture = textura
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.roughness_texture = null
    mat.normal_enabled = false
    if nome_material == "Hair_Transparency":
        mat.albedo_color = Color(0.47, 0.40, 0.37, 1.0)
        mat.alpha_scissor_threshold = 0.52
        mat.roughness = 0.62
    elif nome_material == "Hair_Transparency_0001":
        mat.albedo_color = Color(0.44, 0.38, 0.35, 1.0)
        mat.alpha_scissor_threshold = 0.57
        mat.roughness = 0.69
    elif nome_material == "Hair_Transparency_0002":
        mat.albedo_color = Color(0.42, 0.36, 0.33, 1.0)
        mat.alpha_scissor_threshold = 0.57
        mat.roughness = 0.64
    elif nome_material == "Hair_Transparency_0003":
        # Franja: limiar menor para preservar fios finos sobre a testa.
        mat.albedo_color = Color(0.53, 0.45, 0.41, 1.0)
        mat.alpha_scissor_threshold = 0.24
        mat.roughness = 0.62
    elif nome_material.begins_with("Scalp"):
        mat.albedo_color = Color(0.35, 0.30, 0.28, 1.0)
        mat.alpha_scissor_threshold = 0.22
        mat.roughness = 0.80
    elif nome_material.begins_with("Female_Brow"):
        # Sobrancelha mais fina e escura, parecida com a referencia.
        mat.albedo_color = Color(0.19, 0.15, 0.14, 1.0)
        mat.alpha_scissor_threshold = 0.56
        mat.roughness = 0.92
    else:
        mat.albedo_color = Color.WHITE
        mat.alpha_scissor_threshold = 0.30
        mat.roughness = 0.88

func _carregar_textura_multi(caminhos: Array) -> Texture2D:
    for caminho in caminhos:
        var tex := _carregar_textura(caminho)
        if tex != null:
            return tex
    return null

func _carregar_textura(caminho: String) -> Texture2D:
    if _cache_texturas.has(caminho):
        return _cache_texturas[caminho]
    if not ResourceLoader.exists(caminho):
        _cache_texturas[caminho] = null
        return null
    var tex := load(caminho) as Texture2D
    _cache_texturas[caminho] = tex
    return tex
