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
        var distancia: float = foco.distance_to(m.global_position)
        var deve_ativar: bool = distancia <= (DISTANCIA_ATIVACAO if not m.visible else DISTANCIA_DESATIVACAO)
        if deve_ativar != m.visible:
            m.visible = deve_ativar
            if "physics_process" in m:
                m.set_physics_process(deve_ativar)
