extends Camera3D
## Camera de terceira pessoa real: mostra Amber inteira e nunca fica colada no rosto.
@export var alvo: NodePath = NodePath("../Amber")
@export var distancia: float = 2.65
@export var distancia_minima: float = 2.40
@export var altura_alvo: float = 0.98
@export var elevacao: float = 0.13
var azimute: float = 0.0
var dedo_camera: int = -1
var arrastando_mouse: bool = false
var _aviso_alvo: bool = false
var _inicializado: bool = false

func _ready() -> void:
    current = true
    near = 0.08
    far = 1500.0
    fov = 58.0
    _definir_azimute_inicial()
    _atualizar(false)

func _physics_process(_delta: float) -> void:
    if get_viewport().get_camera_3d() != self:
        current = true
        make_current()
    if not _inicializado:
        _definir_azimute_inicial()
    _atualizar(true)

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var toque: InputEventScreenTouch = event
        if toque.pressed and dedo_camera == -1 and _area_camera(toque.position):
            dedo_camera = toque.index
        elif not toque.pressed and toque.index == dedo_camera:
            dedo_camera = -1
    elif event is InputEventScreenDrag:
        var arraste: InputEventScreenDrag = event
        if arraste.index == dedo_camera:
            _girar(arraste.relative)
    elif event is InputEventMouseButton:
        var botao: InputEventMouseButton = event
        if botao.button_index == MOUSE_BUTTON_LEFT:
            arrastando_mouse = botao.pressed and _area_camera(botao.position)
    elif event is InputEventMouseMotion:
        var mouse: InputEventMouseMotion = event
        if arrastando_mouse:
            _girar(mouse.relative)

func cancelar_arrasto() -> void:
    dedo_camera = -1
    arrastando_mouse = false

func girar_analogico(movimento: Vector2) -> void:
    _girar(movimento)

func _area_camera(pos: Vector2) -> bool:
    var mapa: Node = get_node_or_null("../Mapa_Interativo")
    if mapa != null and mapa.call("area_reservada", pos):
        return false
    var hud: Node = get_node_or_null("../Controles_Android/HUD")
    if hud != null and hud.call("area_controle", pos):
        return false
    var tela: Vector2 = get_viewport().get_visible_rect().size
    if tela.x <= 0.0 or tela.y <= 0.0:
        return true
    return pos.y < tela.y * 0.64 or (pos.x > tela.x * 0.35 and pos.x < tela.x * 0.82)

func _girar(movimento: Vector2) -> void:
    azimute -= movimento.x * 0.006
    elevacao = clampf(elevacao + movimento.y * 0.0035, 0.05, 0.55)

func _definir_azimute_inicial() -> void:
    var personagem: CharacterBody3D = get_node_or_null(alvo) as CharacterBody3D
    if personagem == null:
        return
    var visual: Node3D = personagem.get_node_or_null("Modelo_Amber") as Node3D
    if visual != null:
        var atras: Vector3 = visual.global_basis.z.normalized()
        azimute = atan2(atras.x, atras.z)
    else:
        azimute = PI
    _inicializado = true

func _atualizar(verificar_colisao: bool) -> void:
    var personagem: CharacterBody3D = get_node_or_null(alvo) as CharacterBody3D
    if personagem == null:
        if not _aviso_alvo:
            push_warning("Camera 3P: Amber nao encontrada em ../Amber.")
            _aviso_alvo = true
        return
    var centro: Vector3 = personagem.global_position + Vector3.UP * altura_alvo
    var vetor_atras: Vector3 = Vector3(sin(azimute), 0.0, cos(azimute)).normalized()
    var candidato: Vector3 = centro + vetor_atras * distancia + Vector3.UP * (distancia * elevacao)
    var destino: Vector3 = candidato
    if verificar_colisao:
        destino = _resolver_colisao(personagem, centro, candidato, vetor_atras)
    global_position = destino
    look_at(centro + Vector3.UP * 0.15, Vector3.UP)

func _resolver_colisao(personagem: CharacterBody3D, centro: Vector3, candidato: Vector3, vetor_atras: Vector3) -> Vector3:
    var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(centro, candidato)
    ray.collision_mask = 1
    ray.exclude = [personagem.get_rid()]
    var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
    if hit.is_empty():
        return candidato
    var impacto: Vector3 = hit["position"]
    var livre: float = centro.distance_to(impacto) - 0.28
    if livre >= distancia_minima:
        return centro + vetor_atras * livre + Vector3.UP * maxf(0.35, livre * elevacao)
    # Se houver parede muito perto, sobe e afasta em vez de virar primeira pessoa.
    return centro + vetor_atras * distancia_minima + Vector3.UP * 0.65
