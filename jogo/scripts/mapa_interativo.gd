extends CanvasLayer
## Minimap clicavel e mapa geral com informacoes de locais, ponte, mar e posicao da Amber.
const DESENHO = preload("res://scripts/mapa_desenho.gd")

var aberto: bool = false
var _amber: CharacterBody3D
var _hud: Control
var _mini: Control
var _botao_mapa: Button
var _overlay: Control
var _sombra: ColorRect
var _painel: Panel
var _mapa_grande: Control
var _info: RichTextLabel
var _titulo: Label
var _botao_fechar: Button
var _selecionado: String = "amber"
var _relogio: float = 0.0
var _ultima_posicao: Vector2 = Vector2.ZERO
var _tem_posicao: bool = false
var _rastro_tempo: float = 0.0

func _ready() -> void:
    layer = 20 # acima do HUD no Android
    _amber = get_node_or_null("../Amber") as CharacterBody3D
    _hud = get_node_or_null("../Controles_Android/HUD") as Control
    _criar_minimapa()
    _criar_mapa_grande()
    get_viewport().size_changed.connect(_reposicionar)
    _reposicionar()
    _atualizar()

func area_reservada(posicao: Vector2) -> bool:
    return aberto or Rect2(Vector2(10, 8), Vector2(178, 164)).has_point(posicao)

func _criar_minimapa() -> void:
    _botao_mapa = Button.new()
    _botao_mapa.name = "AbrirMapa"
    _botao_mapa.text = "MAPA  (TOCAR)"
    _botao_mapa.position = Vector2(15, 12)
    _botao_mapa.size = Vector2(158, 46)
    _botao_mapa.pressed.connect(_abrir)
    add_child(_botao_mapa)
    _mini = DESENHO.new() as Control
    _mini.name = "MiniMapa"
    _mini.position = Vector2(15, 63)
    _mini.size = Vector2(158, 102)
    _mini.clip_contents = true # recorta ruas e terreno fora do zoom local
    _mini.mouse_filter = Control.MOUSE_FILTER_STOP
    _mini.gui_input.connect(_toque_minimapa)
    add_child(_mini)

func _criar_mapa_grande() -> void:
    _overlay = Control.new()
    _overlay.name = "MapaCompleto"
    _overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    _overlay.visible = false
    add_child(_overlay)

    _sombra = ColorRect.new()
    _sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _sombra.color = Color(0.02, 0.05, 0.08, 0.91)
    _sombra.mouse_filter = Control.MOUSE_FILTER_STOP
    _overlay.add_child(_sombra)

    _painel = Panel.new()
    _painel.mouse_filter = Control.MOUSE_FILTER_STOP
    _overlay.add_child(_painel)

    _titulo = Label.new()
    _titulo.text = "MAPA DE AMBERCITY  |  Duas cidades e uma ponte"
    _titulo.add_theme_font_size_override("font_size", 21)
    _titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _painel.add_child(_titulo)

    _botao_fechar = Button.new()
    _botao_fechar.text = "FECHAR  X"
    _botao_fechar.pressed.connect(_fechar)
    _painel.add_child(_botao_fechar)

    _mapa_grande = DESENHO.new() as Control
    _mapa_grande.set("completo", true)
    _mapa_grande.mouse_filter = Control.MOUSE_FILTER_STOP
    _mapa_grande.gui_input.connect(_toque_mapa_grande)
    _painel.add_child(_mapa_grande)

    _info = RichTextLabel.new()
    _info.name = "Informacoes"
    _info.bbcode_enabled = true
    _info.scroll_active = true
    _info.mouse_filter = Control.MOUSE_FILTER_STOP
    _painel.add_child(_info)

func _reposicionar() -> void:
    if _overlay == null or _painel == null:
        return
    var tela: Vector2 = get_viewport().get_visible_rect().size
    _overlay.size = tela
    _sombra.size = tela
    _painel.position = Vector2(12, 12)
    _painel.size = tela - Vector2(24, 24)
    _titulo.position = Vector2(15, 8)
    _titulo.size = Vector2(maxf(180, tela.x - 190), 38)
    _botao_fechar.size = Vector2(124, 46)
    _botao_fechar.position = Vector2(_painel.size.x - 133, 6)
    var conteudo: Vector2 = _painel.size - Vector2(30, 76)
    var largura_info: float = clampf(conteudo.x * 0.30, 176.0, 315.0)
    var largura_mapa: float = maxf(155.0, conteudo.x - largura_info - 12.0)
    _mapa_grande.position = Vector2(14, 55)
    _mapa_grande.size = Vector2(largura_mapa, maxf(120.0, conteudo.y))
    _info.position = Vector2(26 + largura_mapa, 55)
    _info.size = Vector2(largura_info, maxf(120.0, conteudo.y))
    _mapa_grande.queue_redraw()

func _toque_minimapa(evento: InputEvent) -> void:
    if evento is InputEventScreenTouch and evento.pressed:
        _abrir()
        _mini.accept_event()
    elif evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
        _abrir()
        _mini.accept_event()

func _toque_mapa_grande(evento: InputEvent) -> void:
    var clique: Vector2 = Vector2.ZERO
    if evento is InputEventScreenTouch:
        if not evento.pressed:
            return
        clique = evento.position
    elif evento is InputEventMouseButton:
        if not evento.pressed or evento.button_index != MOUSE_BUTTON_LEFT:
            return
        clique = evento.position
    else:
        return
    _selecionado = str(_mapa_grande.call("zona_em", clique))
    _atualizar_info()
    _mapa_grande.accept_event()

func _abrir() -> void:
    if aberto:
        return
    aberto = true
    _overlay.visible = true
    if _hud == null:
        _hud = get_node_or_null("../Controles_Android/HUD") as Control
    if _hud != null:
        _hud.call("_zerar_controles")
        _hud.set_process_input(false)
        _hud.set_process(false)
    if _amber != null:
        _amber.call("definir_controles_ativos", false)
    var camera: Camera3D = get_node_or_null("../Camera3D") as Camera3D
    if camera != null:
        camera.call("cancelar_arrasto")
    _atualizar()

func _fechar() -> void:
    if not aberto:
        return
    aberto = false
    _overlay.visible = false
    if _hud != null:
        _hud.set_process_input(true)
        _hud.set_process(true)
    if _amber != null:
        _amber.call("definir_controles_ativos", _hud == null or not bool(_hud.get("configuracoes_abertas")))

func _unhandled_input(evento: InputEvent) -> void:
    if aberto and evento is InputEventKey and evento.pressed and not evento.echo and evento.keycode == KEY_ESCAPE:
        _fechar()
        get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
    # Ler a posicao REAL da Amber em todos os quadros, inclusive ao correr ou atravessar a ponte.
    if not is_instance_valid(_amber):
        _amber = get_node_or_null("../Amber") as CharacterBody3D
        _tem_posicao = false
    if _amber == null or _mini == null or _mapa_grande == null:
        return
    var p: Vector3 = _amber.global_position
    var atual: Vector2 = Vector2(p.x, p.z)
    var andou: float = atual.distance_to(_ultima_posicao) if _tem_posicao else 0.0
    var direcao: Vector2 = (atual - _ultima_posicao).normalized() if andou > 0.005 else Vector2.ZERO
    _mini.set("jogador", p)
    _mapa_grande.set("jogador", p)
    if andou > 0.005:
        _mini.set("direcao", direcao)
        _mapa_grande.set("direcao", direcao)
    # Minimap ~110 x 74 m. Amber anda visivelmente; a vista segue com suavidade na borda.
    var centro: Vector2 = _mini.get("mini_centro") as Vector2
    if absf(atual.x - centro.x) > 37.0 or absf(atual.y - centro.y) > 23.0:
        _mini.set("mini_centro", centro.lerp(atual, minf(delta * 1.9, 1.0)))
    _rastro_tempo += delta
    if not _tem_posicao or (andou > 0.005 and _rastro_tempo >= 0.20):
        _mini.call("adicionar_rastro", atual)
        _mapa_grande.call("adicionar_rastro", atual)
        _rastro_tempo = 0.0
    _ultima_posicao = atual
    _tem_posicao = true
    # Coordenadas no botao: leitura verificavel mesmo quando se move so 1 metro.
    _botao_mapa.text = "MAPA  X:%d Z:%d" % [roundi(p.x), roundi(p.z)]
    _mini.queue_redraw()
    if aberto:
        _mapa_grande.queue_redraw()
        _relogio += delta
        if _relogio >= 0.15:
            _relogio = 0.0
            _atualizar_info()

func _atualizar() -> void:
    # Atualizacao inicial e ao abrir o mapa; o movimento continuo fica em _process.
    if not is_instance_valid(_amber):
        _amber = get_node_or_null("../Amber") as CharacterBody3D
    if _amber != null:
        _mini.set("jogador", _amber.global_position)
        _mapa_grande.set("jogador", _amber.global_position)
        if not _tem_posicao:
            var p: Vector3 = _amber.global_position
            _ultima_posicao = Vector2(p.x, p.z)
            _mini.set("mini_centro", _ultima_posicao)
            _mini.call("adicionar_rastro", _ultima_posicao)
            _mapa_grande.call("adicionar_rastro", _ultima_posicao)
            _tem_posicao = true
    _mini.queue_redraw()
    if aberto:
        _mapa_grande.queue_redraw()
        _atualizar_info()

func _atualizar_info() -> void:
    if _info == null:
        return
    var local: String = ""
    match _selecionado:
        "amber": local = "[b]Cidade da Amber[/b]\nSolo e colisao: 500 x 500 m.\nCentro: X 0, Z 0.\n64 casas e 64 predios adicionais (modelos simplificados), alem do centro original."
        "ponte": local = "[b]Ponte entre cidades[/b]\nAtravesse de leste para oeste pelo centro do mapa.\nTrecho: X 239,5 a 335,5 m; Z proximo de 0.\nLargura: 12 m, com colisao no piso e nas laterais."
        "externa": local = "[b]Segunda cidade[/b]\nModelo enviado: grid_system.fbx.\nCentro da ilha: X 475, Z 0.\nBase da ilha: 300 x 240 m.\nRuas/edificios internos do FBX nao foram mapeados individualmente."
        _: local = "[b]Mar[/b]\nArea visual: 1600 x 1300 m.\nAo redor das duas ilhas; agua apenas visual, sem navegacao implementada."
    var p: Vector3 = Vector3.ZERO if _amber == null else _amber.global_position
    _info.text = "[b]LOCAL SELECIONADO[/b]\n" + local + "\n\n[b]AMBER AGORA[/b]\nX: %.1f m\nZ: %.1f m\n\n[b]REFERENCIAS[/b]\nVermelho: Amber\nVerde: areas de terra\nCinza: ponte e ruas\nAzul: mar\n\nToque na cidade, ponte, outra ilha ou mar para consultar." % [p.x, p.z]
