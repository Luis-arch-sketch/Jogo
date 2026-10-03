extends Node3D
## Expande o AmberCity com mar, uma segunda cidade procedural e uma ponte limpa ligando as duas areas.
## Evita depender do FBX para a jogabilidade no Android.

@export var centro_cidade_externa: Vector3 = Vector3(475.0, 0.02, 0.0)
@export var tamanho_ilha_externa: Vector3 = Vector3(300.0, 0.2, 240.0)
@export var tamanho_mar: Vector3 = Vector3(1600.0, 2.2, 1300.0)

var _asfalto: StandardMaterial3D
var _calcada: StandardMaterial3D
var _predio: StandardMaterial3D
var _casa: StandardMaterial3D
var _telhado: StandardMaterial3D
var _janela: StandardMaterial3D
var _porta: StandardMaterial3D

func _ready() -> void:
    _preparar_materiais()
    _expandir_limites_base()
    _criar_mar()
    _criar_ilha_externa()
    _criar_ponte()
    _criar_cidade_externa_procedural()

func _preparar_materiais() -> void:
    _asfalto = StandardMaterial3D.new()
    _asfalto.albedo_color = Color(0.18, 0.19, 0.20, 1.0)
    _asfalto.roughness = 0.92
    _calcada = StandardMaterial3D.new()
    _calcada.albedo_color = Color(0.74, 0.76, 0.77, 1.0)
    _calcada.roughness = 0.95
    _predio = StandardMaterial3D.new()
    _predio.albedo_color = Color(0.70, 0.72, 0.75, 1.0)
    _predio.roughness = 0.92
    _casa = StandardMaterial3D.new()
    _casa.albedo_color = Color(0.78, 0.75, 0.66, 1.0)
    _casa.roughness = 0.95
    _telhado = StandardMaterial3D.new()
    _telhado.albedo_color = Color(0.34, 0.22, 0.20, 1.0)
    _telhado.roughness = 0.90
    _janela = StandardMaterial3D.new()
    _janela.albedo_color = Color(0.27, 0.43, 0.54, 1.0)
    _janela.roughness = 0.28
    _janela.metallic = 0.15
    _porta = StandardMaterial3D.new()
    _porta.albedo_color = Color(0.18, 0.15, 0.14, 1.0)
    _porta.roughness = 0.74

func _expandir_limites_base() -> void:
    var base: Node3D = get_node_or_null("../Base") as Node3D
    if base == null:
        return
    var oeste := base.get_node_or_null("Limite_Oeste") as StaticBody3D
    var leste := base.get_node_or_null("Limite_Leste") as StaticBody3D
    var norte := base.get_node_or_null("Limite_Norte") as StaticBody3D
    var sul := base.get_node_or_null("Limite_Sul") as StaticBody3D
    if oeste != null:
        oeste.position = Vector3(-599.6, 3.0, 0.0)
        var col_oeste := oeste.get_node_or_null("Colisao") as CollisionShape3D
        if col_oeste != null and col_oeste.shape is BoxShape3D:
            (col_oeste.shape as BoxShape3D).size = Vector3(0.8, 6.0, 1300.0)
    if leste != null:
        leste.position = Vector3(999.6, 3.0, 0.0)
        var col_leste := leste.get_node_or_null("Colisao") as CollisionShape3D
        if col_leste != null and col_leste.shape is BoxShape3D:
            (col_leste.shape as BoxShape3D).size = Vector3(0.8, 6.0, 1300.0)
    if norte != null:
        norte.position = Vector3(200.0, 3.0, -649.6)
        var col_norte := norte.get_node_or_null("Colisao") as CollisionShape3D
        if col_norte != null and col_norte.shape is BoxShape3D:
            (col_norte.shape as BoxShape3D).size = Vector3(1600.0, 6.0, 0.8)
    if sul != null:
        sul.position = Vector3(200.0, 3.0, 649.6)
        var col_sul := sul.get_node_or_null("Colisao") as CollisionShape3D
        if col_sul != null and col_sul.shape is BoxShape3D:
            (col_sul.shape as BoxShape3D).size = Vector3(1600.0, 6.0, 0.8)

func _criar_mar() -> void:
    var mar := MeshInstance3D.new()
    mar.name = "Mar_Visual"
    var malha := BoxMesh.new()
    malha.size = tamanho_mar
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.12, 0.35, 0.52, 1.0)
    mat.roughness = 0.10
    mat.metallic = 0.04
    mat.emission_enabled = true
    mat.emission = Color(0.02, 0.08, 0.10, 1.0)
    malha.material = mat
    mar.mesh = malha
    mar.position = Vector3(200.0, -1.22, 0.0)
    mar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mar)

func _criar_ilha_externa() -> void:
    var ilha := StaticBody3D.new()
    ilha.name = "Ilha_Cidade_Externa"
    ilha.position = Vector3(centro_cidade_externa.x, -0.1, centro_cidade_externa.z)
    ilha.collision_layer = 1
    ilha.collision_mask = 1
    add_child(ilha)

    var visual := MeshInstance3D.new()
    var malha := BoxMesh.new()
    malha.size = tamanho_ilha_externa
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.33, 0.43, 0.35, 1.0)
    mat.roughness = 1.0
    malha.material = mat
    visual.mesh = malha
    ilha.add_child(visual)

    var colisao := CollisionShape3D.new()
    var forma := BoxShape3D.new()
    forma.size = tamanho_ilha_externa
    colisao.shape = forma
    ilha.add_child(colisao)

func _criar_ponte() -> void:
    var ponte := StaticBody3D.new()
    ponte.name = "Ponte_Entre_Cidades"
    ponte.position = Vector3(287.5, 0.0, 0.0)
    ponte.collision_layer = 1
    ponte.collision_mask = 1
    add_child(ponte)

    var deck := MeshInstance3D.new()
    var deck_mesh := BoxMesh.new()
    deck_mesh.size = Vector3(96.0, 0.14, 14.0)
    deck_mesh.material = _asfalto
    deck.mesh = deck_mesh
    ponte.add_child(deck)

    var col := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(96.0, 0.14, 14.0)
    col.shape = shape
    ponte.add_child(col)

    var faixa_mat := StandardMaterial3D.new()
    faixa_mat.albedo_color = Color(0.86, 0.87, 0.82, 1.0)
    faixa_mat.roughness = 0.88
    for i in range(7):
        var linha := MeshInstance3D.new()
        var linha_mesh := BoxMesh.new()
        linha_mesh.size = Vector3(5.5, 0.01, 0.18)
        linha_mesh.material = faixa_mat
        linha.mesh = linha_mesh
        linha.position = Vector3(-33.0 + float(i) * 11.0, 0.08, 0.0)
        ponte.add_child(linha)

    var guarda_mesh := BoxMesh.new()
    guarda_mesh.size = Vector3(96.0, 0.85, 0.22)
    var guarda_mat := StandardMaterial3D.new()
    guarda_mat.albedo_color = Color(0.85, 0.87, 0.90, 1.0)
    guarda_mat.roughness = 0.52
    guarda_mesh.material = guarda_mat
    for z in [-6.6, 6.6]:
        var guarda := MeshInstance3D.new()
        guarda.mesh = guarda_mesh
        guarda.position = Vector3(0.0, 0.46, z)
        ponte.add_child(guarda)
        var barreira := CollisionShape3D.new()
        var barreira_forma := BoxShape3D.new()
        barreira_forma.size = Vector3(96.0, 0.85, 0.22)
        barreira.shape = barreira_forma
        barreira.position = Vector3(0.0, 0.46, z)
        ponte.add_child(barreira)

    var pilar_mesh := BoxMesh.new()
    pilar_mesh.size = Vector3(2.4, 5.0, 2.4)
    var pilar_mat := StandardMaterial3D.new()
    pilar_mat.albedo_color = Color(0.62, 0.65, 0.68, 1.0)
    pilar_mat.roughness = 0.95
    pilar_mesh.material = pilar_mat
    for x in [-34.0, -10.0, 14.0, 38.0]:
        var pilar := MeshInstance3D.new()
        pilar.mesh = pilar_mesh
        pilar.position = Vector3(x, -2.55, 0.0)
        ponte.add_child(pilar)

func _criar_cidade_externa_procedural() -> void:
    var cidade := Node3D.new()
    cidade.name = "Outra_Cidade"
    cidade.position = centro_cidade_externa
    add_child(cidade)

    _bloco(cidade, "Avenida_X", Vector3(0.0, 0.03, 0.0), Vector3(260.0, 0.02, 11.0), _asfalto)
    _bloco(cidade, "Avenida_Z", Vector3(0.0, 0.031, 0.0), Vector3(11.0, 0.02, 180.0), _asfalto)
    for x in [-92.0, 92.0]:
        _bloco(cidade, "Rua_X", Vector3(0.0, 0.032, x), Vector3(260.0, 0.02, 9.0), _asfalto)
    for z in [-64.0, 64.0]:
        _bloco(cidade, "Rua_Z", Vector3(z, 0.033, 0.0), Vector3(9.0, 0.02, 180.0), _asfalto)

    var indice: int = 0
    for px in [-105.0, -55.0, 55.0, 105.0]:
        for pz in [-78.0, -28.0, 28.0, 78.0]:
            if abs(px) < 20.0 and abs(pz) < 20.0:
                continue
            var altura: float = 12.0 + float((indice % 4) * 5)
            _predio_caixa(cidade, Vector3(px, 0.0, pz), Vector3(18.0, altura, 16.0), "Predio_%d" % indice)
            indice += 1

    var casa_i: int = 0
    for px in [-118.0, -82.0, -22.0, 22.0, 82.0, 118.0]:
        for pz in [-104.0, 104.0]:
            _casa_caixa(cidade, Vector3(px, 0.0, pz), Vector3(13.0, 5.0, 14.0), "Casa_%d" % casa_i)
            casa_i += 1

func _bloco(pai: Node3D, nome: String, local: Vector3, tamanho: Vector3, mat: Material) -> void:
    var objeto := MeshInstance3D.new()
    objeto.name = nome
    var mesh := BoxMesh.new()
    mesh.size = tamanho
    mesh.material = mat
    objeto.mesh = mesh
    objeto.position = local
    objeto.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    pai.add_child(objeto)

func _predio_caixa(pai: Node3D, pos: Vector3, tam: Vector3, nome: String) -> void:
    var corpo := StaticBody3D.new()
    corpo.name = nome
    corpo.position = pos
    corpo.collision_layer = 1
    corpo.collision_mask = 1
    pai.add_child(corpo)
    var visual := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = tam
    mesh.material = _predio
    visual.mesh = mesh
    visual.position = Vector3(0.0, tam.y * 0.5, 0.0)
    corpo.add_child(visual)
    var col := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = tam
    col.shape = shape
    col.position = Vector3(0.0, tam.y * 0.5, 0.0)
    corpo.add_child(col)
    _bloco(corpo, "Cobertura", Vector3(0.0, tam.y + 0.12, 0.0), Vector3(tam.x + 0.4, 0.24, tam.z + 0.4), _telhado)
    var janela_mesh := BoxMesh.new()
    janela_mesh.size = Vector3(1.3, 1.4, 0.08)
    janela_mesh.material = _janela
    for andar in range(maxi(3, int(floor((tam.y - 2.0) / 3.1)))):
        for coluna in [-1.0, 0.0, 1.0]:
            var j := MeshInstance3D.new()
            j.mesh = janela_mesh
            j.position = Vector3(coluna * tam.x * 0.24, 2.4 + float(andar) * 3.1, -tam.z * 0.5 - 0.05)
            corpo.add_child(j)
    _bloco(corpo, "Porta", Vector3(0.0, 1.2, -tam.z * 0.5 - 0.05), Vector3(1.55, 2.4, 0.09), _porta)

func _casa_caixa(pai: Node3D, pos: Vector3, tam: Vector3, nome: String) -> void:
    var corpo := StaticBody3D.new()
    corpo.name = nome
    corpo.position = pos
    corpo.collision_layer = 1
    corpo.collision_mask = 1
    pai.add_child(corpo)
    var visual := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = tam
    mesh.material = _casa
    visual.mesh = mesh
    visual.position = Vector3(0.0, tam.y * 0.5, 0.0)
    corpo.add_child(visual)
    var col := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = tam
    col.shape = shape
    col.position = Vector3(0.0, tam.y * 0.5, 0.0)
    corpo.add_child(col)
    _bloco(corpo, "Telhado", Vector3(0.0, tam.y + 0.2, 0.0), Vector3(tam.x + 0.6, 0.35, tam.z + 0.6), _telhado)
    _bloco(corpo, "Porta", Vector3(0.0, 1.1, -tam.z * 0.5 - 0.05), Vector3(1.15, 2.2, 0.09), _porta)
    for coluna in [-1.0, 1.0]:
        _bloco(corpo, "Janela", Vector3(coluna * tam.x * 0.22, 2.35, -tam.z * 0.5 - 0.05), Vector3(1.05, 0.9, 0.08), _janela)
