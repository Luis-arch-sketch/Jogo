extends Node3D
## Loja de Armas física de AmberCity: um prédio com letreiro luminoso na praça.
## O jogador precisa chegar perto (menos de 16 m) e tocar no botao LOJA do HUD
## para abrir o catalogo e comprar armas com o dinheiro ganho.

## Catálogo de armas da loja de AmberCity + estado do jogador (dinheiro e armas).
## Os preços são pensados para o jogo começar com a pistola já comprada;
## as demais exigem voltar à Loja de Armas para comprar.
const RAIO_INTERACAO: float = 16.0

func _ready() -> void:
    randomize()
    _criar_predio()
    _criar_letreiro()
    _criar_bolsos_de_dinheiro()

func _criar_predio() -> void:
    var corpo := MeshInstance3D.new()
    var caixa := BoxMesh.new()
    caixa.size = Vector3(12.0, 7.0, 9.0)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.34, 0.37, 0.42)
    mat.roughness = 0.85
    caixa.material = mat
    corpo.mesh = caixa
    corpo.position = Vector3(0, 3.5, 0)
    add_child(corpo)
    # Colisao simples para o jogador nao atravessar a loja.
    var area := Area3D.new()
    area.name = "LojaArea"
    var col := CollisionShape3D.new()
    var forma := BoxShape3D.new()
    forma.size = Vector3(12.6, 7.2, 9.6)
    col.shape = forma
    col.position = Vector3(0, 3.6, 0)
    area.add_child(col)
    add_child(area)
    # Porta escura + vitrine iluminada.
    var porta := MeshInstance3D.new()
    var pbox := BoxMesh.new()
    pbox.size = Vector3(2.4, 3.4, 0.3)
    var pmat := StandardMaterial3D.new()
    pmat.albedo_color = Color(0.1, 0.09, 0.08)
    pbox.material = pmat
    porta.mesh = pbox
    porta.position = Vector3(-3.0, 1.7, 4.6)
    add_child(porta)
    var vidro := MeshInstance3D.new()
    var vbox := BoxMesh.new()
    vbox.size = Vector3(6.5, 2.6, 0.25)
    var vmat := StandardMaterial3D.new()
    vmat.albedo_color = Color(0.55, 0.75, 0.9, 0.5)
    vmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    vmat.emission_enabled = true
    vmat.emission = Color(0.5, 0.7, 0.95)
    vmat.emission_energy_multiplier = 0.9
    vbox.material = vmat
    vidro.mesh = vbox
    vidro.position = Vector3(2.2, 2.4, 4.65)
    add_child(vidro)

func _criar_letreiro() -> void:
    var letreiro := Label3D.new()
    letreiro.name = "Letreiro_Loja"
    letreiro.text = "LOJA DE ARMAS"
    letreiro.font_size = 62
    letreiro.outline_size = 12
    letreiro.pixel_size = 0.012
    letreiro.position = Vector3(0, 6.2, 4.75)
    letreiro.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    letreiro.modulate_color = Color(1.0, 0.85, 0.35)
    add_child(letreiro)
    var aviso := Label3D.new()
    aviso.name = "Aviso_Perto"
    aviso.text = ""
    aviso.font_size = 40
    aviso.pixel_size = 0.012
    aviso.position = Vector3(0, 8.2, 4.75)
    aviso.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(aviso)

## Dinheiro espalhado pela cidade: bônus que o jogador coleta andando por cima.
func _criar_bolsos_de_dinheiro() -> void:
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var multidao := get_node_or_null("../Multidao_Cidade")
    for i in range(26):
        var bolsa := Area3D.new()
        bolsa.name = "Dinheiro_%d" % i
        var valor: int = [25, 40, 60, 80][rng.randi_range(0, 3)]
        var mesh := MeshInstance3D.new()
        var caixa := BoxMesh.new()
        caixa.size = Vector3(0.55, 0.22, 0.4)
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.15, 0.55, 0.28)
        mat.emission_enabled = true
        mat.emission = Color(0.2, 0.9, 0.4)
        mat.emission_energy_multiplier = 1.4
        caixa.material = mat
        mesh.mesh = caixa
        bolsa.add_child(mesh)
        var col := CollisionShape3D.new()
        var esfera := SphereShape3D.new()
        esfera.radius = 1.1
        col.shape = esfera
        bolsa.add_child(col)
        # Posiciona em pontos aleatórios dentro da área central da cidade.
        var angulo := rng.randf() * TAU
        var distancia := rng.randf_range(14.0, 130.0)
        bolsa.position = Vector3(cos(angulo) * distancia, 0.35, sin(angulo) * distancia)
        bolsa.body_entered.connect(_pegar_dinheiro.bind(bolsa, valor))
        add_child(bolsa)

func _pegar_dinheiro(corpo: Node, bolsa: Area3D, valor: int) -> void:
    if corpo is CharacterBody3D and String(corpo.name) == "Amber":
        var armas := get_node_or_null("../Armas")
        if armas != null:
            armas.set("dinheiro", int(armas.get("dinheiro")) + valor)
        bolsa.queue_free()

func _process(delta: float) -> void:
    var aviso := get_node_or_null("Aviso_Perto") as Label3D
    if aviso == null:
        return
    var amber := get_node_or_null("../Amber") as Node3D
    if amber == null:
        return
    var distancia: float = amber.global_position.distance_to(global_position)
    if distancia <= RAIO_INTERACAO:
        aviso.text = "Voce esta na Loja! Toque no botao LOJA"
    elif distancia < 60.0:
        aviso.text = "Loja de Armas a %.0f m" % distancia
    else:
        aviso.text = ""

## Chamado pelo HUD para saber se o jogador está perto o suficiente.
func esta_perto(de: Vector3) -> bool:
    return global_position.distance_to(de) <= RAIO_INTERACAO

const ARMAS: Array[Dictionary] = [
    {"id": "punho",  "nome": "Punhos",        "custo": 0,    "dano": 15,  "alcance": 2.6,  "cadencia": 0.45, "auto": false,
     "descricao": "Soco corpo a corpo. De graça, mas bem perto do alvo."},
    {"id": "faca",   "nome": "Faca tática",   "custo": 150,  "dano": 38,  "alcance": 3.0,  "cadencia": 0.35, "auto": false,
     "descricao": "Silenciosa e rápida. Encoste no morador para golpear."},
    {"id": "pistola","nome": "Pistola 9 mm",  "custo": 400,  "dano": 34,  "alcance": 70.0, "cadencia": 0.28, "auto": false,
     "descricao": "Tiro certinho na mira. A clássica da cidade."},
    {"id": "escopeta","nome": "Escopeta",     "custo": 950,  "dano": 62,  "alcance": 28.0, "cadencia": 0.85, "auto": false,
     "descricao": "Devastadora de perto. Cada chumbo dói em dobro."},
    {"id": "smg",    "nome": "Submetralhadora","custo": 1500,"dano": 22,  "alcance": 55.0, "cadencia": 0.10, "auto": true,
     "descricao": "Automática: segure o dedo e varra a rua inteira."},
    {"id": "rifle",  "nome": "Rifle AK-Real", "custo": 2600, "dano": 58,  "alcance": 95.0, "cadencia": 0.13, "auto": true,
     "descricao": "Potência máxima, longo alcance. O terror do bairro."},
]

static func obter(id: String) -> Dictionary:
    for a in ARMAS:
        if String(a["id"]) == id:
            return a
    return ARMAS[0]

static func por_id(id: String) -> int:
    for i in range(ARMAS.size()):
        if String(ARMAS[i]["id"]) == id:
            return i
    return 0
