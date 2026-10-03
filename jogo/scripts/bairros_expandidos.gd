extends Node3D
## 8 bairros ao redor do centro original (grade de 3 x 3 quadras de 80 m).
## Edificios leves gerados localmente, sem rede e sem NPCs/bots.
const PASSO: float = 80.0
var asfalto: StandardMaterial3D
var passeio: StandardMaterial3D
var parede: Array[StandardMaterial3D] = []
var vidros: StandardMaterial3D
var portas: StandardMaterial3D
var telhado: StandardMaterial3D
var faixa: StandardMaterial3D

func _ready() -> void:
    asfalto = _material(Color(0.94, 0.95, 0.96), 0.96, "res://assets/texturas_cidade/asfalto.png", 14.0)
    passeio = _material(Color(0.96, 0.96, 0.95), 0.97, "res://assets/texturas_cidade/concreto_calcada.png", 12.0)
    vidros = _material(Color(0.32, 0.48, 0.58), 0.28)
    vidros.metallic = 0.35
    portas = _material(Color(0.15, 0.19, 0.22), 0.52)
    telhado = _material(Color(0.22, 0.25, 0.26), 0.85)
    faixa = _material(Color(0.78, 0.76, 0.67), 0.95)
    parede = [
        _material(Color(0.51, 0.53, 0.51), 0.92),
        _material(Color(0.60, 0.57, 0.52), 0.92),
        _material(Color(0.48, 0.54, 0.58), 0.91),
        _material(Color(0.61, 0.61, 0.58), 0.92)
    ]
    for ix in range(-1, 2):
        for iz in range(-1, 2):
            if ix == 0 and iz == 0:
                continue  # preserva os 4 edificios 3D originais no centro.
            _criar_bairro(Vector3(float(ix) * PASSO, 0.0, float(iz) * PASSO), ix, iz)

func _material(cor: Color, aspereza: float, caminho: String = "", repeticao: float = 1.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = cor
    m.roughness = aspereza
    if caminho != "":
        m.albedo_texture = load(caminho) as Texture2D
        m.uv1_scale = Vector3(repeticao, repeticao, repeticao)
    return m

func _bloco(pai: Node3D, nome: String, pos: Vector3, tamanho: Vector3, mat: Material) -> MeshInstance3D:
    var m := MeshInstance3D.new()
    m.name = nome
    var cubo := BoxMesh.new()
    cubo.size = tamanho
    cubo.material = mat
    m.mesh = cubo
    m.position = pos
    m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    pai.add_child(m)
    return m

func _criar_bairro(centro: Vector3, ix: int, iz: int) -> void:
    var bairro := Node3D.new()
    bairro.name = "Bairro_%d_%d" % [ix + 1, iz + 1]
    bairro.position = centro
    add_child(bairro)
    # Malha de avenidas que conecta cada setor ao centro. Sem buracos na colisao:
    # o piso fisico principal cobre os 240 x 240 metros inteiros.
    _bloco(bairro, "Rua_Norte_Sul", Vector3(0, 0.019, 0), Vector3(9.1, 0.012, 80.05), asfalto)
    _bloco(bairro, "Rua_Leste_Oeste", Vector3(0, 0.021, 0), Vector3(80.05, 0.012, 9.1), asfalto)
    var setor: int = 0
    for sx in [-1, 1]:
        for sz in [-1, 1]:
            _bloco(bairro, "Calcada", Vector3(float(sx) * 22.25, 0.030, float(sz) * 22.25), Vector3(35.3, 0.020, 35.3), passeio)
            _edificio(bairro, Vector3(float(sx) * 22.5, 0.0, float(sz) * 22.5), ix, iz, setor, sz)
            setor += 1
    # Pequena sinalizacao para indicar continuidade das ruas.
    for lado in [-1, 1]:
        for passo in range(7):
            var offset: float = float(lado) * (8.0 + float(passo) * 4.2)
            _bloco(bairro, "Linha_Via_NS", Vector3(0, 0.033, offset), Vector3(0.10, 0.006, 1.7), faixa)
            _bloco(bairro, "Linha_Via_LO", Vector3(offset, 0.034, 0), Vector3(1.7, 0.006, 0.10), faixa)

func _edificio(bairro: Node3D, centro: Vector3, ix: int, iz: int, quadrante: int, frente: int) -> void:
    var variacao: int = abs(ix * 7 + iz * 11 + quadrante * 5)
    var altura: float = 8.0 + float(variacao % 5) * 2.3
    var largura: float = 10.0 + float(variacao % 3) * 1.2
    var fundo: float = 10.0 + float((variacao + 1) % 3) * 1.2
    var corpo := StaticBody3D.new()
    corpo.name = "Predio_Leve_%d" % quadrante
    corpo.position = centro
    bairro.add_child(corpo)
    var visual := MeshInstance3D.new()
    var malha := BoxMesh.new()
    malha.size = Vector3(largura, altura, fundo)
    malha.material = parede[variacao % parede.size()]
    visual.mesh = malha
    visual.position.y = altura * 0.5
    corpo.add_child(visual)
    var col := CollisionShape3D.new()
    var caixa := BoxShape3D.new()
    caixa.size = Vector3(largura, altura, fundo)
    col.shape = caixa
    col.position.y = altura * 0.5
    corpo.add_child(col)
    _bloco(corpo, "Cobertura", Vector3(0, altura + 0.12, 0), Vector3(largura + 0.22, 0.24, fundo + 0.22), telhado)
    # Janelas 3D instanciadas: um draw call por fachada, leve no Android.
    var janela_mesh := BoxMesh.new()
    janela_mesh.size = Vector3(1.12, 1.18, 0.08)
    janela_mesh.material = vidros
    var andares: int = maxi(2, int(floor((altura - 1.6) / 2.4)))
    var janelas := MultiMesh.new()
    janelas.transform_format = MultiMesh.TRANSFORM_3D
    janelas.mesh = janela_mesh
    janelas.instance_count = andares * 3
    var z_frente: float = -float(frente) * (fundo * 0.5 + 0.06)
    for piso in range(andares):
        for coluna in range(3):
            var x: float = (float(coluna) - 1.0) * (largura * 0.26)
            var y: float = 2.4 + float(piso) * 2.4
            janelas.set_instance_transform(piso * 3 + coluna, Transform3D(Basis.IDENTITY, Vector3(x, y, z_frente)))
    var fachada := MultiMeshInstance3D.new()
    fachada.name = "Janelas_Instanciadas"
    fachada.multimesh = janelas
    fachada.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    corpo.add_child(fachada)
    _bloco(corpo, "Porta", Vector3(0, 1.12, z_frente), Vector3(1.55, 2.24, 0.09), portas)
