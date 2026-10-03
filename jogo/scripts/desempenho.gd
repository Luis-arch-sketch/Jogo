extends Node
## Seis perfis 3D, incluindo MAX 4K, sMax 8K e iMAX 10K.
## Nomes sMax/iMAX nao garantem renderizacao real a 8K/10K.
## O jogo usa stretch canvas_items para desenhar o 3D na resolucao fisica.
## No Android, sMax e iMAX ficam limitados a 2x da resolucao fisica.
const ARQUIVO: String = "user://amber_graficos.cfg"
const LARGURA_MAX: float = 3840.0
const ALTURA_MAX: float = 2160.0
const LARGURA_SMAX: float = 7680.0
const ALTURA_SMAX: float = 4320.0
const LARGURA_IMAX: float = 10240.0
const ALTURA_IMAX: float = 5760.0
var perfil: int = 1
var celular: bool = false
var _auto_ajuste_finalizado: bool = false
var _tempo_desde_inicio: float = 0.0
var _amostragem: float = 0.0
var _amostras_baixas: int = 0
var _amostras_validas: int = 0
var _perfil_escolhido: bool = false
var _ultimo_tamanho: Vector2i = Vector2i.ZERO
var _resolucao_3d: Vector2i = Vector2i(960, 540)

func _ready() -> void:
    celular = OS.has_feature("android") or OS.has_feature("ios")
    var cfg := ConfigFile.new()
    if cfg.load(ARQUIVO) == OK:
        perfil = clampi(int(cfg.get_value("graficos", "perfil", 1)), 0, 5)
        _perfil_escolhido = true
    # Liga o 3D ao tamanho real do display, nao ao viewport antigo de 960x540.
    get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    call_deferred("aplicar")

func _process(delta: float) -> void:
    var tamanho: Vector2i = get_window().size
    if tamanho != _ultimo_tamanho and tamanho.x > 0 and tamanho.y > 0:
        aplicar()
    # Ajuste automatico apenas no perfil inicial, nunca nos perfis escolhidos.
    if not celular or _perfil_escolhido or _auto_ajuste_finalizado or perfil == 0:
        return
    _tempo_desde_inicio += delta
    if _tempo_desde_inicio < 5.0:
        return
    _amostragem += delta
    if _amostragem < 0.5:
        return
    _amostragem = 0.0
    var fps: int = Engine.get_frames_per_second()
    if fps > 0:
        _amostras_validas += 1
        if fps < 22:
            _amostras_baixas += 1
    if _tempo_desde_inicio >= 13.0:
        _auto_ajuste_finalizado = true
        if _amostras_validas >= 8 and _amostras_baixas * 3 >= _amostras_validas * 2:
            perfil = maxi(perfil - 1, 0)
            aplicar()
            print("AmberCity: aparelho lento no modo padrao; perfil reduzido. Escolha manual respeitada.")

func nome_perfil() -> String:
    match perfil:
        0: return "ECONOMIA"
        1: return "EQUILIBRADO"
        2: return "VISUAL"
        3: return "MAX 4K"
        4: return "sMax 8K"
        5: return "iMAX 10K"
    return "EQUILIBRADO"

func avancar_perfil() -> void:
    perfil = (perfil + 1) % 6
    _perfil_escolhido = true
    _auto_ajuste_finalizado = true
    var cfg := ConfigFile.new()
    cfg.set_value("graficos", "perfil", perfil)
    var erro: Error = cfg.save(ARQUIVO)
    if erro != OK:
        push_warning("AmberCity: nao foi possivel salvar perfil: %d" % erro)
    aplicar()

func resolucao_texto() -> String:
    return "%d x %d (render 3D)" % [_resolucao_3d.x, _resolucao_3d.y]

func aviso_max() -> String:
    match perfil:
        3:
            if _resolucao_3d.x >= 3840 and _resolucao_3d.y >= 2160:
                return "4K calculado; muito pesado no Android"
            return "MAX 4K: limitado pela tela / GPU"
        4:
            if _resolucao_3d.x >= 7680 and _resolucao_3d.y >= 4320:
                return "8K calculado; consumo extremo de GPU"
            return "sMax 8K: nome do perfil; abaixo de 8K real"
        5:
            if _resolucao_3d.x >= 10240 and _resolucao_3d.y >= 5760:
                return "10K calculado; consumo extremo de GPU"
            return "iMAX 10K: nome do perfil; abaixo de 10K real"
    return ""

func aplicar() -> void:
    var viewport: Viewport = get_viewport()
    var janela: Window = get_window()
    var camera: Camera3D = get_node_or_null("../Camera3D") as Camera3D
    var sol: DirectionalLight3D = get_node_or_null("../Sol") as DirectionalLight3D
    var tela: Vector2i = janela.size
    if tela.x <= 0 or tela.y <= 0:
        tela = Vector2i(960, 540)
    _ultimo_tamanho = tela
    viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
    var escala: float = 1.0
    match perfil:
        0: escala = 0.65
        1: escala = 0.83
        2: escala = 1.0
        3:
            # Alvo 4K; teto de 2x em qualquer aparelho.
            escala = maxf(1.0, minf(2.0, minf(LARGURA_MAX / float(tela.x), ALTURA_MAX / float(tela.y))))
        4:
            # sMax: alvo 8K, limitado a 2x no Android ou 4x fora dele.
            # Numa tela 1920x1080 no Android, o teto e 3840x2160, nao 8K.
            var teto_smax: float = 2.0 if celular else 4.0
            escala = maxf(1.0, minf(teto_smax, minf(LARGURA_SMAX / float(tela.x), ALTURA_SMAX / float(tela.y))))
        5:
            # iMAX: alvo 10K, com MSAA 2x para diferenciar o nivel visual.
            # Mesmo no iMAX, nunca renderizar 10K automaticamente no Android.
            var teto_imax: float = 2.0 if celular else 4.0
            escala = maxf(1.0, minf(teto_imax, minf(LARGURA_IMAX / float(tela.x), ALTURA_IMAX / float(tela.y))))
    viewport.scaling_3d_scale = escala
    _resolucao_3d = Vector2i(roundi(float(tela.x) * escala), roundi(float(tela.y) * escala))
    # 2x/4x MSAA suaviza as bordas no modo Compatibilidade no Godot 4.3+.
    viewport.msaa_3d = Viewport.MSAA_DISABLED if perfil == 0 or perfil == 3 or perfil == 4 else (Viewport.MSAA_2X if perfil == 1 or perfil == 5 else Viewport.MSAA_4X)
    if celular:
        Engine.max_fps = 30 if perfil == 0 else (45 if perfil == 1 else 60)
    else:
        Engine.max_fps = 45 if perfil == 0 else 60
    if camera != null:
        camera.far = 90.0 if perfil == 0 else (135.0 if perfil == 1 else (175.0 if perfil == 2 else (220.0 if perfil <= 4 else 240.0)))
    if sol != null:
        sol.shadow_enabled = perfil > 0
        sol.directional_shadow_mode = 1
        sol.directional_shadow_max_distance = 25.0 if perfil == 1 else (55.0 if perfil == 2 else (80.0 if perfil <= 4 else 100.0))
    # A luz de recorte e as texturas originais permanecem no projeto.
    print("AmberCity graficos: %s / %s" % [nome_perfil(), resolucao_texto()])
