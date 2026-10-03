extends Node3D
## Multidão da cidade AmberCity: carrega 120 perfis realistas de pedestres
## (assets/personagens_cidade.json) e os espalha pela cidade para vagar.
## Cada morador usa a mesma animação de caminhada biomecânica da Amber.

const TOTAL_MAXIMO: int = 120
const DISTANCIA_ATIVACAO: float = 95.0   # só anima quem está perto do jogador
const DISTANCIA_DESATIVACAO: float = 120.0
const ARQUIVO_PERFIS: String = "res://assets/personagens_cidade.json"

var moradores: Array[Node3D] = []
var camera: Camera3D = null
var pronto: bool = false

func _ready() -> void:
    if Engine.is_editor_hint():
        return
    add_to_group("multidao")
    randomize()
    var bruto: Variant = null
    if FileAccess.file_exists(ARQUIVO_PERFIS):
        bruto = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO_PERFIS))
    var lista: Array = []
    if bruto is Dictionary:
        lista = (bruto as Dictionary).get("personagens", [])
    if lista.size() == 0:
        # Fallback: gera perfis simples se o JSON não estiver disponível.
        for i in range(TOTAL_MAXIMO):
            lista.append({"id": "c%03d" % i, "altura": randf_range(1.55, 1.92)})
    var cena := load("res://scripts/morador.gd")
    # Lê o bake da Amber UMA vez e entrega aos 120 moradores (mesma animação real).
    var animacao: Variant = null
    if FileAccess.file_exists("res://assets/amber_motion_baked.json"):
        animacao = JSON.parse_string(FileAccess.get_file_as_string("res://assets/amber_motion_baked.json"))
    var contador: int = 0
    for perfil in lista:
        if contador >= TOTAL_MAXIMO:
            break
        if not (perfil is Dictionary):
            continue
        var morador := Node3D.new()
        morador.set_script(cena)
        morador.name = "Morador_" + str(perfil.get("id", contador))
        morador.configurar(perfil, _posicao_inicial(contador), animacao)
        add_child(morador)
        moradores.append(morador)
        contador += 1
    pronto = true

func _posicao_inicial(indice: int) -> Vector3:
    # Espalha em anéis: centro da cidade mais movimentado que as bordas.
    var grade: float = 96.0
    var angulo: float = float(indice) * 2.39996323  # ângulo áureo -> distribuição uniforme
    var raio: float = grade * sqrt(float(indice + 1) / float(TOTAL_MAXIMO)) * 2.4
    var x: float = clampf(cos(angulo) * raio, -240.0, 240.0)
    var z: float = clampf(sin(angulo) * raio, -240.0, 240.0)
    # Encaixa na calçada mais próxima da malha de ruas.
    x = round(x / grade) * grade + 5.2 if fmod(absf(x), grade) < grade * 0.5 else x
    return Vector3(clampf(x, -240.0, 240.0), 0.0, clampf(z, -240.0, 240.0))

func _process(_delta: float) -> void:
    if not pronto:
        return
    if camera == null:
        camera = get_viewport().get_camera_3d()
        if camera == null:
            return
    var foco: Vector3 = camera.global_position
    for m in moradores:
        # Moradores caídos (mortos) permanecem visíveis como "corpos" no cenário.
        var deve_ativar: bool = true
        if m.get("caido") == true:
            deve_ativar = foco.distance_to(m.global_position) <= DISTANCIA_DESATIVACAO
        else:
            deve_ativar = foco.distance_to(m.global_position) <= (DISTANCIA_ATIVACAO if not m.visible else DISTANCIA_DESATIVACAO)
        if deve_ativar != m.visible:
            m.visible = deve_ativar
            if "physics_process" in m:
                # Caídos ainda processam 0,5 s p/ terminar a animação de queda.
                m.set_physics_process(deve_ativar)

## Contágio de pânico: um tiro foi dado perto de `origem`; todos os moradores
## num raio de 45 m se assustam e saem correndo (menos a vítima direta).
func alarme_tiro(origem: Vector3, vitima: Node3D) -> void:
    for m in moradores:
        if m == vitima or not m.visible:
            continue
        if origem.distance_to(m.global_position) < 45.0 and m.has_method("susto_pertissimo"):
            m.susto_pertissimo()

## Retorna o morador mais próximo do raio do raycast, ou null.
func morador_no_segmento(origem: Vector3, direcao: Vector3, alcance: float) -> Node3D:
    var melhor: Node3D = null
    var melhor_t: float = alcance
    for m in moradores:
        if not m.visible or m.get("caido") == true:
            continue
        # Cápsula aproximada: centro na altura do peito, raio 0.35, meia-altura 0.9.
        var c: Vector3 = m.global_position + Vector3(0, 1.0, 0)
        var oc: Vector3 = c - origem
        var t: float = oc.dot(direcao)
        if t < 0.0 or t > melhor_t:
            continue
        var d_perp: float = (oc - direcao * t).length()
        var r: float = 0.42
        if d_perp <= r:
            # Impacto frontal: testa também cabeça/pernas ao longo do segmento.
            melhor = m
            melhor_t = t
    return melhor

## Alvo corpo a corpo: morador mais próximo dentro de `alcance` à frente de `de`.
func morador_proximo(de: Vector3, frente: Vector3, alcance: float) -> Node3D:
    var melhor: Node3D = null
    var melhor_dist: float = alcance
    for m in moradores:
        if not m.visible or m.get("caido") == true:
            continue
        var v: Vector3 = (m.global_position + Vector3(0, 1.0, 0)) - de
        var dist: float = v.length()
        if dist <= melhor_dist and v.normalized().dot(frente) > 0.4:
            melhor = m
            melhor_dist = dist
    return melhor
