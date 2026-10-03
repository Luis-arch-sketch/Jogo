extends Node3D
## Cena de teste do controlador que e usado no JOGO (sem falso positivo de GLB).
@onready var amber: CharacterBody3D = $AmberVisual
@onready var controle: Node = $AmberVisual/Animacao_Confiavel
var info: Label

func _ready() -> void:
    var camada := CanvasLayer.new()
    add_child(camada)
    var painel := PanelContainer.new()
    painel.set_anchors_preset(Control.PRESET_TOP_LEFT)
    painel.offset_left = 8.0
    painel.offset_top = 35.0
    painel.offset_right = 450.0
    camada.add_child(painel)
    var coluna := VBoxContainer.new()
    painel.add_child(coluna)
    info = Label.new()
    info.text = "Carregando controlador..."
    coluna.add_child(info)
    var botoes := HBoxContainer.new()
    coluna.add_child(botoes)
    for entrada in [["Parada", "idle"], ["Andar", "walk"], ["Correr", "run"], ["Pular", "jump"]]:
        var botao := Button.new()
        botao.text = entrada[0]
        botao.pressed.connect(_alternar.bind(entrada[1]))
        botoes.add_child(botao)
    var girar := Button.new()
    girar.text = "GIRAR"
    girar.pressed.connect(_girar)
    botoes.add_child(girar)
    amber.set_physics_process(false)
    controle.set_physics_process(false)
    call_deferred("_verificar")

func _verificar() -> void:
    if not bool(controle.get("funcionando")):
        info.text = "FALHA NO CONTROLADOR. Veja a mensagem colorida no topo."
        return
    var esq: Skeleton3D = controle.get("esqueleto") as Skeleton3D
    info.text = "ESQUELETO: %d ossos | 4 movimentos | controle direto\nToque Andar para conferir as PERNAS e BRACOS." % esq.get_bone_count()
    _alternar("walk")

func _process(delta: float) -> void:
    if bool(controle.get("funcionando")):
        var novo_tempo: float = float(controle.get("tempo")) + delta
        controle.set("tempo", novo_tempo)
        controle.call("_aplicar_frame", str(controle.get("animacao_atual")), novo_tempo, 1.0)

func _alternar(nome: String) -> void:
    if not bool(controle.get("funcionando")):
        return
    controle.set("animacao_atual", nome)
    controle.set("tempo", 0.0)
    controle.call("_aplicar_frame", nome, 0.0, 1.0)
    info.text = "ESQUELETO CONTROLADO | %s\nOlhe os bracos e as pernas para confirmar." % nome.to_upper()

func _girar() -> void:
    $AmberVisual/Modelo_Amber.rotate_y(PI / 2.0)
