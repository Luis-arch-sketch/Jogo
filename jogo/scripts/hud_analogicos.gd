extends Control
## Cada analogico acompanha um dedo diferente; mouse tambem pode testar os controles.

var amber: CharacterBody3D
var camera: Camera3D
var desempenho: Node
var armas: ArmasSistema = null       # sistema de armas + dinheiro (nó Armas)
var loja: Node3D = null              # Loja_Armas (prédio comprável na cidade)
var mostrar_toque: bool = false
var configuracoes_abertas: bool = false
var loja_aberta: bool = false
var dedo_esquerdo: int = -1
var dedo_direito: int = -1
var dedo_pulo: int = -1
var dedo_tiro: int = -1
var pos_esquerdo: Vector2 = Vector2.ZERO
var pos_direito: Vector2 = Vector2.ZERO
var entrada_esquerda: Vector2 = Vector2.ZERO
var entrada_direita: Vector2 = Vector2.ZERO
var _feedback: String = ""
var _feedback_tempo: float = 0.0
var _ultimo_dinheiro: int = -1

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    amber = get_node_or_null("../../Amber") as CharacterBody3D
    camera = get_node_or_null("../../Camera3D") as Camera3D
    desempenho = get_node_or_null("../../Desempenho")
    armas = get_node_or_null("../../Armas") as ArmasSistema
    loja = get_node_or_null("../../Loja_Armas")
    if armas != null:
        armas.set_mira(self)
    mostrar_toque = OS.has_feature("android") or OS.has_feature("ios")
    queue_redraw()

func _process(delta: float) -> void:
    # Mostra o grito/reação da IA quando um morador é atingido.
    if armas != null and armas.ultimo_feedback != "" and armas._tempo_feedback > 0.0:
        _feedback = String(armas.ultimo_feedback)
        _feedback_tempo = 2.5
    _feedback_tempo -= delta
    if Input.is_action_just_pressed("ui_accept"):
        _disparo_pc(true)
    if Input.is_action_just_released("ui_accept"):
        _disparo_pc(false)
    if Input.is_key_pressed(KEY_1):
        _trocar_por_tecla(0)
    if Input.is_key_pressed(KEY_2):
        _trocar_por_tecla(1)
    if Input.is_key_pressed(KEY_3):
        _trocar_por_tecla(2)
    if Input.is_key_pressed(KEY_4):
        _trocar_por_tecla(3)
    # O analogico direito gira continuamente enquanto o jogador o mantem inclinado.
    if not configuracoes_abertas and not loja_aberta and camera != null and entrada_direita.length_squared() > 0.0001:
        camera.call("girar_analogico", Vector2(entrada_direita.x * 240.0 * delta, entrada_direita.y * 200.0 * delta))
    queue_redraw()

# ---------------- BOTÕES / ÁREAS DO HUD DE ARMAS ----------------
func _botao_tiro() -> Rect2:
    var tela: Vector2 = _tela()
    return Rect2(Vector2(tela.x - 176.0, tela.y * 0.42), Vector2(148.0, 66.0))

func _botao_loja() -> Rect2:
    var tela: Vector2 = _tela()
    return Rect2(Vector2(tela.x - 176.0, tela.y * 0.42 - 78.0), Vector2(148.0, 58.0))

func _painel_loja() -> Rect2:
    var tela: Vector2 = _tela()
    var largura: float = minf(620.0, tela.x * 0.92)
    var altura: float = minf(430.0, tela.y * 0.94)
    return Rect2((tela - Vector2(largura, altura)) * 0.5, Vector2(largura, altura))

func _loja_fechar() -> Rect2:
    var painel: Rect2 = _painel_loja()
    return Rect2(painel.end - Vector2(120.0, 44.0), Vector2(108.0, 32.0))

func _linha_loja(i: int) -> Rect2:
    var painel: Rect2 = _painel_loja()
    return Rect2(Vector2(painel.position.x + 14.0, painel.position.y + 96.0 + float(i) * 48.0), Vector2(painel.size.x - 28.0, 44.0))

func _dentro_de(rects: Array, posicao: Vector2) -> bool:
    for r in rects:
        if (r as Rect2).has_point(posicao):
            return true
    return false

func _disparo_pc(pressionado: bool) -> void:
    if armas != null:
        armas.teclado_disparo(pressionado)

func _trocar_por_tecla(indice: int) -> void:
    if armas == null:
        return
    if indice < armas.armas_compradas.size():
        armas.definir_arma(armas.armas_compradas[indice])

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        queue_redraw()

func _tela() -> Vector2:
    return get_viewport().get_visible_rect().size

func _raio() -> float:
    var tela: Vector2 = _tela()
    return clampf(minf(tela.x, tela.y) * 0.125, 43.0, 70.0)

func _centro_esquerdo() -> Vector2:
    var tela: Vector2 = _tela()
    var raio: float = _raio()
    return Vector2(raio + 31.0, tela.y - raio - 21.0)

func _centro_direito() -> Vector2:
    var tela: Vector2 = _tela()
    var raio: float = _raio()
    return Vector2(tela.x - raio - 31.0, tela.y - raio - 21.0)

func _centro_pulo() -> Vector2:
    var tela: Vector2 = _tela()
    var raio: float = _raio()
    return Vector2(tela.x - raio * 3.55, tela.y - raio - 21.0)

func _botao_ajuda() -> Rect2:
    return Rect2(Vector2(_tela().x - 172.0, 13.0), Vector2(158.0, 52.0))

func _painel_ajuda() -> Rect2:
    var tela: Vector2 = _tela()
    var dimensao: Vector2 = Vector2(minf(tela.x - 24.0, 660.0), minf(tela.y - 20.0, 460.0))
    return Rect2((tela - dimensao) * 0.5, dimensao)

func _botao_qualidade() -> Rect2:
    var painel: Rect2 = _painel_ajuda()
    return Rect2(Vector2(painel.position.x + 20.0, painel.end.y - 72.0), Vector2(minf(440.0, painel.size.x - 40.0), 52.0))

func _fechar_ajuda() -> Rect2:
    var painel: Rect2 = _painel_ajuda()
    return Rect2(Vector2(painel.end.x - 114.0, painel.position.y + 8.0), Vector2(104.0, 48.0))

func area_controle(posicao: Vector2) -> bool:
    if loja_aberta:
        return true
    if not mostrar_toque:
        return configuracoes_abertas or _botao_ajuda().has_point(posicao) or _botao_tiro().has_point(posicao) or _botao_loja().has_point(posicao)
    if configuracoes_abertas:
        return true
    var raio: float = _raio()
    return _botao_ajuda().has_point(posicao) or _botao_tiro().has_point(posicao) or _botao_loja().has_point(posicao) or posicao.distance_to(_centro_esquerdo()) < raio * 1.48 or posicao.distance_to(_centro_direito()) < raio * 1.48 or posicao.distance_to(_centro_pulo()) < raio * 0.96

func _zerar_controles() -> void:
    dedo_esquerdo = -1
    dedo_direito = -1
    dedo_pulo = -1
    if dedo_tiro != -1 and armas != null:
        armas.toque_disparo(dedo_tiro, false)
    dedo_tiro = -1
    entrada_esquerda = Vector2.ZERO
    entrada_direita = Vector2.ZERO
    pos_esquerdo = _centro_esquerdo()
    pos_direito = _centro_direito()
    if amber != null:
        amber.call("definir_analogico", Vector2.ZERO)
        amber.call("definir_acao", "pular", false)
    if camera != null:
        camera.call("cancelar_arrasto")
    queue_redraw()

func _alternar_ajuda() -> void:
    configuracoes_abertas = not configuracoes_abertas
    _zerar_controles()
    if amber != null:
        amber.call("definir_controles_ativos", not configuracoes_abertas)

func _input(event: InputEvent) -> void:
    if event is InputEventKey:
        var tecla: InputEventKey = event
        if tecla.pressed and not tecla.echo and tecla.keycode == KEY_ESCAPE:
            if loja_aberta:
                loja_aberta = false
                _zerar_controles()
            else:
                _alternar_ajuda()
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenTouch:
        var toque: InputEventScreenTouch = event
        _tocar(toque.index, toque.position, toque.pressed)
    elif event is InputEventScreenDrag:
        var arraste: InputEventScreenDrag = event
        _arrastar(arraste.index, arraste.position, arraste.relative)
    elif event is InputEventMouseButton:
        var botao: InputEventMouseButton = event
        if botao.button_index == MOUSE_BUTTON_LEFT:
            _tocar(-2, botao.position, botao.pressed)
    elif event is InputEventMouseMotion:
        var movimento: InputEventMouseMotion = event
        if dedo_esquerdo == -2 or dedo_direito == -2:
            _arrastar(-2, movimento.position, movimento.relative)

## Abre a Loja de Armas se o jogador estiver perto do prédio da loja.
func _tentar_abrir_loja() -> void:
    if armas == null:
        return
    if loja != null and loja is Node3D:
        if amber == null:
            return
        var amber_pos: Vector3 = amber.global_position
        if amber_pos.distance_to((loja as Node3D).global_position) > 16.0:
            _feedback = "Va ate a LOJA DE ARMAS (predio cinza com letreiro) para comprar!"
            _feedback_tempo = 2.5
            return
    loja_aberta = true
    _zerar_controles()

func _acao_loja(posicao: Vector2) -> void:
    if _loja_fechar().has_point(posicao):
        loja_aberta = false
        queue_redraw()
        return
    var catalogo := preload("res://scripts/loja_armas.gd").ARMAS
    for i in catalogo.size():
        if _linha_loja(i).has_point(posicao):
            var arma: Dictionary = catalogo[i]
            var id: String = String(arma["id"])
            if id in armas.armas_compradas:
                if armas.definir_arma(id):
                    _feedback = "Equipada: " + String(arma["nome"])
                    _feedback_tempo = 2.0
            else:
                var resultado: String = armas.comprar(id)
                match resultado:
                    "ok":
                        _feedback = "Comprada! " + String(arma["nome"])
                    "sem_dinheiro":
                        _feedback = "Dinheiro insuficiente! Acumule mais."
                    _:
                        _feedback = "Voce ja tem essa arma."
                _feedback_tempo = 2.2
            queue_redraw()
            return

func _tocar(indice: int, posicao: Vector2, pressionado: bool) -> void:
    if pressionado:
        if loja_aberta:
            _acao_loja(posicao)
            return
        if configuracoes_abertas:
            if _fechar_ajuda().has_point(posicao):
                _alternar_ajuda()
            elif _botao_qualidade().has_point(posicao):
                if desempenho != null:
                    desempenho.call("avancar_perfil")
                queue_redraw()
            return
        if _botao_ajuda().has_point(posicao):
            _alternar_ajuda()
            return
        if _botao_loja().has_point(posicao):
            _tentar_abrir_loja()
            return
        if _botao_tiro().has_point(posicao):
            dedo_tiro = indice
            if armas != null:
                armas.toque_disparo(indice, true)
            queue_redraw()
            return
        if not mostrar_toque:
            return
        var raio: float = _raio()
        if dedo_esquerdo == -1 and posicao.distance_to(_centro_esquerdo()) <= raio * 1.48:
            dedo_esquerdo = indice
            _mover_esquerdo(posicao)
        elif dedo_direito == -1 and posicao.distance_to(_centro_direito()) <= raio * 1.48:
            dedo_direito = indice
            _mover_direito(posicao)
        elif dedo_pulo == -1 and posicao.distance_to(_centro_pulo()) <= raio * 0.96:
            dedo_pulo = indice
            if amber != null:
                amber.call("definir_acao", "pular", true)
            queue_redraw()
    else:
        if indice == dedo_tiro:
            dedo_tiro = -1
            if armas != null:
                armas.toque_disparo(indice, false)
            queue_redraw()
        if indice == dedo_esquerdo:
            dedo_esquerdo = -1
            entrada_esquerda = Vector2.ZERO
            pos_esquerdo = _centro_esquerdo()
            if amber != null:
                amber.call("definir_analogico", Vector2.ZERO)
        if indice == dedo_direito:
            dedo_direito = -1
            entrada_direita = Vector2.ZERO
            pos_direito = _centro_direito()
        if indice == dedo_pulo:
            dedo_pulo = -1
            if amber != null:
                amber.call("definir_acao", "pular", false)
        queue_redraw()

func _arrastar(indice: int, posicao: Vector2, deslocamento: Vector2) -> void:
    if configuracoes_abertas:
        return
    if indice == dedo_esquerdo:
        _mover_esquerdo(posicao)
    elif indice == dedo_direito:
        _mover_direito(posicao)

func _mover_direito(posicao: Vector2) -> void:
    var centro: Vector2 = _centro_direito()
    entrada_direita = ((posicao - centro) / _raio()).limit_length(1.0)
    if entrada_direita.length() < 0.16:
        entrada_direita = Vector2.ZERO
    pos_direito = centro + entrada_direita * _raio() * 0.74
    queue_redraw()

func _mover_esquerdo(posicao: Vector2) -> void:
    var centro: Vector2 = _centro_esquerdo()
    var vetor: Vector2 = ((posicao - centro) / _raio()).limit_length(1.0)
    if vetor.length() < 0.16:
        vetor = Vector2.ZERO
    entrada_esquerda = Vector2(vetor.x, -vetor.y)
    pos_esquerdo = centro + vetor * _raio() * 0.74
    if amber != null:
        amber.call("definir_analogico", entrada_esquerda)
    queue_redraw()

func _texto(palavra: String, posicao: Vector2, tamanho: int, cor: Color) -> void:
    draw_string(ThemeDB.fallback_font, posicao, palavra, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tamanho, cor)

func _texto_central(palavra: String, posicao: Vector2, largura: float, tamanho: int, cor: Color) -> void:
    draw_string(ThemeDB.fallback_font, posicao, palavra, HORIZONTAL_ALIGNMENT_CENTER, largura, tamanho, cor)

func _draw() -> void:
    var tela: Vector2 = _tela()
    var escala: float = minf(1.0, minf(tela.x / 960.0, tela.y / 540.0))
    var letra: int = maxi(12, roundi(19.0 * escala))
    var fundo: Color = Color(0.06, 0.10, 0.16, 0.54)
    var contorno: Color = Color(0.85, 0.94, 1.0, 0.85)
    var raio: float = _raio()
    var esquerdo: Vector2 = _centro_esquerdo()
    var direito: Vector2 = _centro_direito()
    var pulo: Vector2 = _centro_pulo()
    if mostrar_toque:
        for centro in [esquerdo, direito]:
            draw_circle(centro, raio, fundo)
            draw_arc(centro, raio, 0.0, TAU, 64, contorno, 2.5, true)
    if mostrar_toque:
        var bola_esquerda: Vector2 = pos_esquerdo if dedo_esquerdo != -1 else esquerdo
        var bola_direita: Vector2 = pos_direito if dedo_direito != -1 else direito
        draw_circle(bola_esquerda, raio * 0.40, Color(0.65, 0.88, 1.0, 0.84))
        draw_circle(bola_direita, raio * 0.40, Color(0.65, 0.88, 1.0, 0.84))
        draw_circle(pulo, raio * 0.65, Color(0.23, 0.48, 0.58, 0.9) if dedo_pulo != -1 else fundo)
        draw_arc(pulo, raio * 0.65, 0.0, TAU, 48, contorno, 2.5, true)
        _texto_central("MOVER", esquerdo + Vector2(-raio, -raio - 12.0), raio * 2.0, letra, Color.WHITE)
        _texto_central("CAMERA", direito + Vector2(-raio, -raio - 12.0), raio * 2.0, letra, Color.WHITE)
        _texto_central("PULAR", pulo + Vector2(-raio, 6.0), raio * 2.0, letra, Color.WHITE)
    var ajuda: Rect2 = _botao_ajuda()
    draw_rect(ajuda, Color(0.06, 0.10, 0.16, 0.83), true)
    draw_rect(ajuda, contorno, false, 2.0)
    _texto_central("CONFIG. / PC", ajuda.position + Vector2(0, 33), ajuda.size.x, 19, Color.WHITE)
    # ---------------- HUD DE ARMAS: dinheiro, arma atual, mira, botões ----------------
    if armas != null:
        if armas.dinheiro != _ultimo_dinheiro:
            _ultimo_dinheiro = armas.dinheiro
        _texto("$ " + str(armas.dinheiro), Vector2(16.0, 34.0), letra + 5, Color(0.55, 1.0, 0.6))
        _texto("Arma: " + String(armas.arma_atual["nome"]) + "   (1-" + str(mini(9, armas.armas_compradas.size())) + " troca)", Vector2(16.0, 60.0), letra - 2, Color(1.0, 0.95, 0.7))
        # Reticulo no centro da tela (para onde a camera aponta).
        var meio: Vector2 = tela * 0.5
        var cor_mira := Color(1.0, 0.35, 0.3, 0.9)
        for ang in [0.0, PI / 2.0, PI, TAU]:
            var dir := Vector2(cos(ang), sin(ang))
            draw_line(meio + dir * 7.0, meio + dir * 15.0, cor_mira, 2.5)
        # Botao LOJA e botao de TIRO (funcionam no celular e no PC).
        var b_loja: Rect2 = _botao_loja()
        draw_rect(b_loja, Color(0.24, 0.34, 0.55, 0.9), true)
        draw_rect(b_loja, contorno, false, 2.0)
        _texto_central("LOJA", b_loja.position + Vector2(0, 36), b_loja.size.x, letra, Color.WHITE)
        var b_tiro: Rect2 = _botao_tiro()
        var cor_tiro: Color = Color(0.85, 0.25, 0.2, 0.95) if dedo_tiro != -1 else Color(0.62, 0.16, 0.13, 0.85)
        draw_rect(b_tiro, cor_tiro, true)
        draw_rect(b_tiro, Color(1.0, 0.8, 0.75, 0.9), false, 2.5)
        _texto_central("TIRO", b_tiro.position + Vector2(0, 42), b_tiro.size.x, letra + 4, Color.WHITE)
        # Feedback: grito do morador atingido / compra / arma equipada.
        if _feedback_tempo > 0.0 and _feedback != "":
            _texto_central(_feedback, Vector2(0, tela.y * 0.24), tela.x, letra + 1, Color(1.0, 0.85, 0.4))
    if loja_aberta:
        _desenhar_loja(tela, letra)
    if not configuracoes_abertas:
        return
    draw_rect(Rect2(Vector2.ZERO, tela), Color(0.015, 0.025, 0.04, 0.75), true)
    var painel: Rect2 = _painel_ajuda()
    draw_rect(painel, Color(0.07, 0.12, 0.20, 0.98), true)
    draw_rect(painel, Color(0.7, 0.86, 1.0), false, 2.0)
    var fechar: Rect2 = _fechar_ajuda()
    draw_rect(fechar, Color(0.18, 0.30, 0.43, 1.0), true)
    _texto_central("FECHAR X", fechar.position + Vector2(0, 30), fechar.size.x, letra, Color.WHITE)
    var esquerda: float = painel.position.x + 25.0
    var topo: float = painel.position.y + 46.0
    var passo: float = maxf(21.0, 30.0 * escala)
    _texto("CONFIGURACOES  |  COMO JOGAR", Vector2(esquerda, topo), letra + 2, Color(0.73, 0.92, 1.0))
    topo += passo * 1.4
    _texto("CELULAR (ANDROID)", Vector2(esquerda, topo), letra, Color(0.96, 0.87, 0.54))
    topo += passo
    _texto("Analogico esquerdo: movimentar a Amber.", Vector2(esquerda, topo), letra, Color.WHITE)
    topo += passo
    _texto("Analogico direito: girar a camera continuamente.", Vector2(esquerda, topo), letra, Color.WHITE)
    topo += passo
    _texto("PULAR: salto.", Vector2(esquerda, topo), letra, Color.WHITE)
    topo += passo * 1.3
    _texto("COMPUTADOR (PC)", Vector2(esquerda, topo), letra, Color(0.96, 0.87, 0.54))
    topo += passo
    _texto("W A S D ou setas: movimentar.", Vector2(esquerda, topo), letra, Color.WHITE)
    topo += passo
    _texto("Segure o botao esquerdo e arraste: olhar.", Vector2(esquerda, topo), letra, Color.WHITE)
    topo += passo
    _texto("ESPACO: pular.   ESC: abrir/fechar ajuda.", Vector2(esquerda, topo), letra, Color.WHITE)
    topo += passo * 1.3
    _texto("Ande na direcao para a qual a camera olha.", Vector2(esquerda, topo), letra, Color(0.73, 0.92, 1.0))
    var qualidade: Rect2 = _botao_qualidade()
    draw_rect(qualidade, Color(0.20, 0.39, 0.36, 1.0), true)
    draw_rect(qualidade, contorno, false, 2.0)
    var modo: String = desempenho.call("nome_perfil") if desempenho != null else "ECONOMIA"
    _texto_central("GRAFICOS: " + modo + "  >", qualidade.position + Vector2(0.0, 23.0), qualidade.size.x, letra, Color.WHITE)
    if desempenho != null:
        _texto_central(str(desempenho.call("resolucao_texto")), qualidade.position + Vector2(0.0, 43.0), qualidade.size.x, maxi(11, letra - 4), Color(0.81, 1.0, 0.88))
        var aviso: String = str(desempenho.call("aviso_max"))
        if aviso != "":
            _texto(aviso, Vector2(esquerda, qualidade.position.y - 12.0), maxi(11, letra - 4), Color(1.0, 0.83, 0.59))

## Painel da Loja de Armas: catálogo, preços, comprar/equipar com um toque.
func _desenhar_loja(tela: Vector2, letra: int) -> void:
    draw_rect(Rect2(Vector2.ZERO, tela), Color(0.01, 0.02, 0.035, 0.8), true)
    var painel: Rect2 = _painel_loja()
    draw_rect(painel, Color(0.08, 0.11, 0.17, 0.98), true)
    draw_rect(painel, Color(0.85, 0.75, 0.4), false, 2.0)
    _texto_central("LOJA DE ARMAS DE AMBERCITY", Vector2(painel.position.x, painel.position.y + 40.0), painel.size.x, letra + 3, Color(1.0, 0.9, 0.55))
    _texto("$ " + str(armas.dinheiro), Vector2(painel.position.x + 20.0, painel.position.y + 68.0), letra + 2, Color(0.55, 1.0, 0.6))
    _texto("toque numa arma para comprar ou equipar", Vector2(painel.position.x + 120.0, painel.position.y + 68.0), letra - 4, Color(0.75, 0.85, 0.95))
    var fechar: Rect2 = _loja_fechar()
    draw_rect(fechar, Color(0.5, 0.2, 0.18, 1.0), true)
    _texto_central("FECHAR X", fechar.position + Vector2(0, 22), fechar.size.x, letra - 3, Color.WHITE)
    var catalogo := preload("res://scripts/loja_armas.gd").ARMAS
    for i in catalogo.size():
        var arma: Dictionary = catalogo[i]
        var linha: Rect2 = _linha_loja(i)
        if linha.end.y > painel.end.y - 12.0:
            break
        var id: String = String(arma["id"])
        var comprada: bool = id in armas.armas_compradas
        var equipada: bool = String(armas.arma_atual["id"]) == id
        var fundo_cor: Color = Color(0.16, 0.34, 0.24, 0.95) if equipada else (Color(0.2, 0.28, 0.4, 0.9) if comprada else Color(0.12, 0.15, 0.2, 0.9))
        draw_rect(linha, fundo_cor, true)
        draw_rect(linha, Color(0.6, 0.7, 0.85, 0.7), false, 1.5)
        var nome: String = String(arma["nome"])
        var etiqueta: String = nome
        if equipada:
            etiqueta += "  [EQUIPADA]"
        elif comprada:
            etiqueta += "  [TOQUE P/ EQUIPAR]"
        else:
            etiqueta += "  -  $" + str(int(arma["custo"])) + "   dano " + str(int(arma["dano"]))
        _texto(etiqueta, linha.position + Vector2(10.0, 28.0), letra - 1, Color.WHITE if comprada else Color(0.92, 0.92, 0.85))
