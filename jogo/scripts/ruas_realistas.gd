extends Node3D
## Detalhes urbanos leves: texturas reais de piso, meios-fios, faixa de pedestre,
## postes e canteiros. O jogador permanece sob controle humano, sem IA.
## Os modelos 3D originais e os controles foram preservados.

var asfalto: StandardMaterial3D
var concreto: StandardMaterial3D
var terra: StandardMaterial3D
var tinta_branca: StandardMaterial3D
var tinta_amarela: StandardMaterial3D
var guia: StandardMaterial3D
var ferro: StandardMaterial3D
var folha: StandardMaterial3D
var folha_clara: StandardMaterial3D
var tronco: StandardMaterial3D
var vidro: StandardMaterial3D

func _ready() -> void:
    asfalto = _material(Color(0.94, 0.95, 0.96), 0.96, "res://assets/texturas_cidade/asfalto.png", 14.0)
    asfalto.normal_enabled = true
    asfalto.normal_texture = load("res://assets/texturas_cidade/asfalto_normal.png")
    concreto = _material(Color(0.96, 0.96, 0.95), 0.98, "res://assets/texturas_cidade/concreto_calcada.png", 12.0)
    terra = _material(Color(0.79, 0.83, 0.74), 1.0, "res://assets/texturas_cidade/terra.png", 2.0)
    tinta_branca = _material(Color(0.80, 0.79, 0.72), 0.93)
    tinta_amarela = _material(Color(0.70, 0.61, 0.32), 0.95)
    guia = _material(Color(0.57, 0.56, 0.52), 0.92)
    ferro = _material(Color(0.15, 0.18, 0.19), 0.55)
    ferro.metallic = 0.70
    folha = _material(Color(0.19, 0.29, 0.16), 0.96)
    folha_clara = _material(Color(0.28, 0.34, 0.17), 0.96)
    tronco = _material(Color(0.30, 0.20, 0.14), 0.99)
    vidro = _material(Color(0.60, 0.70, 0.71), 0.24)
    vidro.metallic = 0.36
    _pavimentos()
    _sinalizacao()
    _equipamentos()
    _canteiros()

func _material(cor: Color, aspereza: float, caminho: String = "", repeticao: float = 1.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = cor
    material.roughness = aspereza
    if caminho != "":
        material.albedo_texture = load(caminho) as Texture2D
        material.uv1_scale = Vector3(repeticao, repeticao, repeticao)
    return material

func _bloco(titulo: String, local: Vector3, tamanho: Vector3, acabamento: Material, sombra: bool = false) -> void:
    var objeto := MeshInstance3D.new()
    objeto.name = titulo
    var forma := BoxMesh.new()
    forma.size = tamanho
    forma.material = acabamento
    objeto.mesh = forma
    objeto.position = local
    if not sombra:
        objeto.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(objeto)

func _cilindro(titulo: String, local: Vector3, raio: float, altura: float, acabamento: Material, lados: int = 9) -> void:
    var objeto := MeshInstance3D.new()
    objeto.name = titulo
    var forma := CylinderMesh.new()
    forma.top_radius = raio
    forma.bottom_radius = raio
    forma.height = altura
    forma.radial_segments = lados
    forma.material = acabamento
    objeto.mesh = forma
    objeto.position = local
    add_child(objeto)

func _copa(titulo: String, local: Vector3, raio: float, acabamento: Material) -> void:
    var objeto := MeshInstance3D.new()
    objeto.name = titulo
    var forma := SphereMesh.new()
    forma.radius = raio
    forma.height = raio * 1.75
    forma.radial_segments = 9
    forma.rings = 5
    forma.material = acabamento
    objeto.mesh = forma
    objeto.position = local
    add_child(objeto)

func _pavimentos() -> void:
    # Base existente permanece: os revestimentos ficam acima dela sem brigar pelo mesmo pixel.
    _bloco("Asfalto_NS", Vector3(0, 0.019, 0), Vector3(9.1, 0.012, 79.2), asfalto)
    _bloco("Asfalto_LO", Vector3(0, 0.021, 0), Vector3(79.2, 0.012, 9.1), asfalto)
    for lado_x in [-1.0, 1.0]:
        for lado_z in [-1.0, 1.0]:
            var cx: float = lado_x * 22.25
            var cz: float = lado_z * 22.25
            _bloco("Calcada_Concreto", Vector3(cx, 0.030, cz), Vector3(35.3, 0.020, 35.3), concreto)
    # Quatro guias internas, sem colisão para evitar prender a Amber nos degraus.
    for lado in [-1.0, 1.0]:
        for centro_z in [-22.5, 22.5]:
            _bloco("Guia_NS", Vector3(lado * 4.61, 0.059, centro_z), Vector3(0.14, 0.075, 34.6), guia)
        for centro_x in [-22.5, 22.5]:
            _bloco("Guia_LO", Vector3(centro_x, 0.059, lado * 4.61), Vector3(34.6, 0.075, 0.14), guia)

func _sinalizacao() -> void:
    # Pintura gasta e discreta: linhas centrais interrompidas na interseção.
    for eixo in [-1.0, 1.0]:
        for faixa in range(8):
            var d: float = eixo * (9.7 + float(faixa) * 3.15)
            _bloco("Linha_Central_NS", Vector3(0, 0.030, d), Vector3(0.12, 0.006, 1.9), tinta_amarela)
            _bloco("Linha_Central_LO", Vector3(d, 0.032, 0), Vector3(1.9, 0.006, 0.12), tinta_amarela)
        _bloco("Borda_Rua_NS", Vector3(eixo * 4.05, 0.028, -22.4), Vector3(0.09, 0.005, 32.0), tinta_branca)
        _bloco("Borda_Rua_NS", Vector3(eixo * 4.05, 0.028, 22.4), Vector3(0.09, 0.005, 32.0), tinta_branca)
        _bloco("Borda_Rua_LO", Vector3(-22.4, 0.029, eixo * 4.05), Vector3(32.0, 0.005, 0.09), tinta_branca)
        _bloco("Borda_Rua_LO", Vector3(22.4, 0.029, eixo * 4.05), Vector3(32.0, 0.005, 0.09), tinta_branca)
    # Quatro faixas de pedestre próximas à interseção.
    for indice in range(9):
        var desloc: float = (float(indice) - 4.0) * 0.84
        for z in [-6.25, 6.25]:
            _bloco("Faixa_Pedestre", Vector3(desloc, 0.031, z), Vector3(0.53, 0.006, 2.05), tinta_branca)
        for x in [-6.25, 6.25]:
            _bloco("Faixa_Pedestre", Vector3(x, 0.031, desloc), Vector3(2.05, 0.006, 0.53), tinta_branca)
    for x in [-3.45, 3.45]:
        for z in [-17.0, 23.0]:
            _cilindro("Tampa_De_Bueiro", Vector3(x, 0.036, z), 0.38, 0.018, ferro, 16)

func _equipamentos() -> void:
    for x in [-5.20, 5.20]:
        for z in [-29.0, -13.0, 13.0, 29.0]:
            _cilindro("Poste_Metalico", Vector3(x, 2.15, z), 0.065, 4.3, ferro, 8)
            var orientacao: float = -1.0 if x < 0.0 else 1.0
            _bloco("Braco_Luminaria", Vector3(x - orientacao * 0.40, 4.18, z), Vector3(0.86, 0.075, 0.07), ferro)
            _bloco("Luminaria_Vidro", Vector3(x - orientacao * 0.77, 4.12, z), Vector3(0.22, 0.055, 0.27), vidro)

func _canteiros() -> void:
    # Vegetação perto das calçadas, sem interferir nos acessos dos prédios.
    var locais: Array[Vector2] = [Vector2(-10.5, -9.8), Vector2(10.5, -9.8), Vector2(-10.5, 10.5), Vector2(10.5, 10.5), Vector2(-9.8, -30.0), Vector2(9.8, -30.0), Vector2(-9.8, 30.0), Vector2(9.8, 30.0)]
    var n: int = 0
    for local in locais:
        var px: float = local.x
        var pz: float = local.y
        _bloco("Terra_Canteiro", Vector3(px, 0.044, pz), Vector3(1.45, 0.014, 2.05), terra)
        _bloco("Borda_Canteiro", Vector3(px, 0.063, pz - 1.04), Vector3(1.6, 0.075, 0.10), guia)
        _bloco("Borda_Canteiro", Vector3(px, 0.063, pz + 1.04), Vector3(1.6, 0.075, 0.10), guia)
        _bloco("Borda_Canteiro", Vector3(px - 0.77, 0.063, pz), Vector3(0.1, 0.075, 2.08), guia)
        _bloco("Borda_Canteiro", Vector3(px + 0.77, 0.063, pz), Vector3(0.1, 0.075, 2.08), guia)
        _cilindro("Tronco", Vector3(px, 1.00, pz), 0.13, 1.93, tronco)
        _copa("Folhagem", Vector3(px, 2.44, pz), 0.86, folha)
        _copa("Folhagem_Lateral", Vector3(px + (0.28 if n % 2 == 0 else -0.23), 2.84, pz + 0.24), 0.61, folha_clara)
        _copa("Folhagem_Alta", Vector3(px - 0.18, 3.14, pz - 0.10), 0.48, folha)
        n += 1
