extends Control
## Mapa vetorial aproximado com posicoes em metros da cena; nenhum dado de ruas internas do FBX e inventado.
const X_MIN: float = -280.0
const X_MAX: float = 650.0
const Z_MIN: float = -290.0
const Z_MAX: float = 290.0

var completo: bool = false
var jogador: Vector3 = Vector3.ZERO
var selecionado: String = ""
var mini_centro: Vector2 = Vector2(0.0, 7.0) # mundo: X e Z
var direcao: Vector2 = Vector2(0.0, -1.0)
var rastro: Array[Vector2] = []
const MINI_LARGURA_METROS: float = 110.0
const MINI_ALTURA_METROS: float = 74.0

func adicionar_rastro(ponto: Vector2) -> void:
    if rastro.is_empty() or rastro[-1].distance_to(ponto) >= 0.25:
        rastro.append(ponto)
        if rastro.size() > 65:
            rastro.remove_at(0)

func _world_to_map(x: float, z: float) -> Vector2:
    if not completo:
        # Zoom LOCAL: 1 metro percorre ~1,4 px em vez de 0,15 px.
        return Vector2(size.x * 0.5 + (x - mini_centro.x) * size.x / MINI_LARGURA_METROS,
            size.y * 0.5 + (z - mini_centro.y) * size.y / MINI_ALTURA_METROS)
    var largura: float = maxf(size.x - 20.0, 1.0)
    var altura: float = maxf(size.y - 20.0, 1.0)
    return Vector2(10.0 + (x - X_MIN) / (X_MAX - X_MIN) * largura, 10.0 + (z - Z_MIN) / (Z_MAX - Z_MIN) * altura)

func _world_rect(x0: float, z0: float, x1: float, z1: float) -> Rect2:
    return Rect2(_world_to_map(x0, z0), _world_to_map(x1, z1) - _world_to_map(x0, z0))

func zona_em(pixel: Vector2) -> String:
    var x: float = ler_x(pixel)
    var z: float = ler_z(pixel)
    if x >= 239.5 and x <= 335.5 and absf(z) <= 6.0:
        return "ponte"
    if absf(x) <= 250.0 and absf(z) <= 250.0:
        return "amber"
    if x >= 325.0 and x <= 625.0 and absf(z) <= 120.0:
        return "externa"
    return "mar"

func ler_x(pixel: Vector2) -> float:
    return X_MIN + (pixel.x - 10.0) / maxf(size.x - 20.0, 1.0) * (X_MAX - X_MIN)

func ler_z(pixel: Vector2) -> float:
    return Z_MIN + (pixel.y - 10.0) / maxf(size.y - 20.0, 1.0) * (Z_MAX - Z_MIN)

func _desenhar_jogador(raio: float) -> void:
    if rastro.size() >= 2:
        for i in range(1, rastro.size()):
            var a: Vector2 = _world_to_map(rastro[i - 1].x, rastro[i - 1].y)
            var b: Vector2 = _world_to_map(rastro[i].x, rastro[i].y)
            draw_line(a, b, Color(1.0, 0.80, 0.39, 0.88), 2.0, true)
    var marcador: Vector2 = _world_to_map(jogador.x, jogador.z)
    if direcao.length_squared() > 0.0001:
        var rumo: Vector2 = direcao.normalized()
        draw_line(marcador, marcador + rumo * (raio + 11.0), Color.WHITE, 2.8, true)
    draw_circle(marcador, raio + 2.0, Color(0.05, 0.08, 0.11, 0.92))
    draw_circle(marcador, raio, Color(1.0, 0.22, 0.17))
    draw_arc(marcador, raio + 3.0, 0.0, TAU, 24, Color.WHITE, 1.4)

func _desenhar_minimapa() -> void:
    # Mapa com camera local: as ruas deslizam sob a Amber e o rastro mostra o caminho.
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.28, 0.45), true)
    draw_rect(_world_rect(-250.0, -250.0, 250.0, 250.0), Color(0.35, 0.47, 0.35), true)
    draw_rect(_world_rect(325.0, -120.0, 625.0, 120.0), Color(0.37, 0.47, 0.38), true)
    draw_rect(_world_rect(239.5, -6.0, 335.5, 6.0), Color(0.65, 0.68, 0.72), true)
    for i in range(-3, 4):
        var rua: float = float(i) * 80.0
        draw_line(_world_to_map(rua, -250.0), _world_to_map(rua, 250.0), Color(0.19, 0.22, 0.23), 2.0)
        draw_line(_world_to_map(-250.0, rua), _world_to_map(250.0, rua), Color(0.19, 0.22, 0.23), 2.0)
    _desenhar_jogador(5.0)
    var fonte: Font = get_theme_default_font()
    if fonte != null:
        draw_string(fonte, Vector2(5.0, size.y - 5.0), "AMBER: X %d  Z %d" % [roundi(jogador.x), roundi(jogador.z)], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

func _draw() -> void:
    if not completo:
        _desenhar_minimapa()
        return
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.28, 0.45), true)
    # Os limites a seguir sao medidos a partir das geometrias/posicoes do projeto.
    draw_rect(_world_rect(-250, -250, 250, 250), Color(0.35, 0.47, 0.35), true)
    draw_rect(_world_rect(325, -120, 625, 120), Color(0.37, 0.47, 0.38), true)
    draw_rect(_world_rect(-250, -250, 250, 250), Color(0.82, 0.91, 0.72), false, 2.0)
    draw_rect(_world_rect(325, -120, 625, 120), Color(0.82, 0.91, 0.72), false, 2.0)
    if completo:
        # Grade simbolica: a distribuicao de lotes representa bairros, nao e planta cadastral.
        for coord in [-200.0, -120.0, -40.0, 40.0, 120.0, 200.0]:
            draw_line(_world_to_map(coord, -245), _world_to_map(coord, 245), Color(0.30, 0.33, 0.33), 2.0)
            draw_line(_world_to_map(-245, coord), _world_to_map(245, coord), Color(0.30, 0.33, 0.33), 2.0)
        # Centro original e bairros novos: blocos esquematicos, nao modelos importados.
        for ix in range(-2, 3):
            for iz in range(-2, 3):
                if ix == 0 and iz == 0:
                    continue
                var x: float = float(ix) * 80.0
                var z: float = float(iz) * 80.0
                draw_rect(_world_rect(x - 22, z - 22, x - 6, z - 6), Color(0.78, 0.70, 0.55), true)
                draw_rect(_world_rect(x + 6, z + 6, x + 22, z + 22), Color(0.73, 0.76, 0.78), true)
    # Ponte sobre o canal entre as ilhas (239,5 a 335,5 m no eixo X).
    draw_rect(_world_rect(239.5, -6, 335.5, 6), Color(0.78, 0.81, 0.84), true)
    draw_line(_world_to_map(239.5, 0), _world_to_map(335.5, 0), Color(0.26, 0.29, 0.32), 2.0)
    _desenhar_jogador(6.0)
    if completo:
        var fonte: Font = get_theme_default_font()
        if fonte != null:
            draw_string(fonte, _world_to_map(-221, -225), "AMBERCITY 500 x 500 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
            draw_string(fonte, _world_to_map(356, -85), "OUTRA CIDADE", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
            draw_string(fonte, _world_to_map(256, -15), "PONTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
            draw_string(fonte, _world_to_map(20, -267), "MAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.87, 0.95, 1.0))
            draw_string(fonte, Vector2(16, size.y - 12.0), "Ponto vermelho: Amber  |  toque em um lugar para ver detalhes", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
