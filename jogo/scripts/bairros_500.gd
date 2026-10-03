extends Node3D
## Anel de bairros para expandir a cidade da Amber a 500 x 500 metros.
## 16 setores x 8 lotes = 64 casas e 64 predios novos.
## Mesmas malhas em MultiMesh para reduzir chamadas de desenho no Android.

const PASSO: float = 96.0
const LADO: float = 96.0
const RUA: float = 9.2

var asfalto: StandardMaterial3D
var calcada: StandardMaterial3D
var tinta: StandardMaterial3D
var vidro: StandardMaterial3D
var telha: StandardMaterial3D
var porta: StandardMaterial3D
var casa_parede: StandardMaterial3D
var predio_parede: StandardMaterial3D
var cubo: BoxMesh

func _ready() -> void:
    asfalto = _mat(Color(0.20, 0.21, 0.22), 0.94)
    calcada = _mat(Color(0.55, 0.55, 0.52), 0.95)
    tinta = _mat(Color(0.81, 0.78, 0.62), 0.90)
    vidro = _mat(Color(0.28, 0.41, 0.49), 0.24)
    vidro.metallic = 0.22
    telha = _mat(Color(0.31, 0.19, 0.17), 0.92)
    porta = _mat(Color(0.19, 0.16, 0.14), 0.77)
    casa_parede = _mat(Color(0.67, 0.65, 0.57), 0.96)
    predio_parede = _mat(Color(0.51, 0.55, 0.57), 0.91)
    cubo = BoxMesh.new()
    cubo.size = Vector3.ONE
    _criar_avenidas()
    for ix in range(-2, 3):
        for iz in range(-2, 3):
            if abs(ix) <= 1 and abs(iz) <= 1:
                continue # preserva o centro e os oito bairros ja existentes.
            _bairro(ix, iz)

func _mat(cor: Color, rugosidade: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = cor
    m.roughness = rugosidade
    return m

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

func _criar_avenidas() -> void:
    # Vias centrais ligam a cidade antiga a nova margem e a ponte no lado leste.
    _bloco(self, "Avenida_Ponte_Leste_Oeste", Vector3(0.0, 0.047, 0.0), Vector3(500.0, 0.012, RUA), asfalto)
    _bloco(self, "Avenida_Norte_Sul", Vector3(0.0, 0.048, 0.0), Vector3(RUA, 0.012, 500.0), asfalto)
    # Malha perimetral nas quadras novas, sem atravessar os predios originais.
    for p in [-192.0, 192.0]:
        _bloco(self, "Via_Transversal", Vector3(0.0, 0.051, p), Vector3(500.0, 0.012, RUA), asfalto)
        _bloco(self, "Via_Longitudinal", Vector3(p, 0.052, 0.0), Vector3(RUA, 0.012, 500.0), asfalto)
    # Linhas guia curtas na avenida de acesso a ponte.
    for i in range(14):
        var x: float = 120.0 + float(i) * 9.0
        _bloco(self, "Faixa_Ponte", Vector3(x, 0.057, 0.0), Vector3(3.2, 0.006, 0.12), tinta)

func _registrar(arr: Array[Transform3D], ponto: Vector3, tamanho: Vector3) -> void:
    arr.append(Transform3D(Basis.IDENTITY.scaled(tamanho), ponto))

func _multimalha(pai: Node3D, nome: String, mat: Material, transforms: Array[Transform3D]) -> void:
    if transforms.is_empty():
        return
    var mesh := BoxMesh.new()
    mesh.size = Vector3.ONE
    mesh.material = mat
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = mesh
    mm.instance_count = transforms.size()
    for i in range(transforms.size()):
        mm.set_instance_transform(i, transforms[i])
    var inst := MultiMeshInstance3D.new()
    inst.name = nome
    inst.multimesh = mm
    inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    pai.add_child(inst)

func _bairro(ix: int, iz: int) -> void:
    var bairro := Node3D.new()
    bairro.name = "Bairro_500_%d_%d" % [ix, iz]
    bairro.position = Vector3(float(ix) * PASSO, 0.0, float(iz) * PASSO)
    add_child(bairro)
    _bloco(bairro, "Rua_NS", Vector3(0.0, 0.038, 0.0), Vector3(RUA, 0.012, LADO), asfalto)
    _bloco(bairro, "Rua_LO", Vector3(0.0, 0.039, 0.0), Vector3(LADO, 0.012, RUA), asfalto)
    for sx in [-1.0, 1.0]:
        for sz in [-1.0, 1.0]:
            _bloco(bairro, "Calcada", Vector3(sx * 25.0, 0.041, sz * 24.0), Vector3(39.0, 0.015, 36.0), calcada)

    var casas: Array[Transform3D] = []
    var predios: Array[Transform3D] = []
    var telhados: Array[Transform3D] = []
    var janelas: Array[Transform3D] = []
    var portas: Array[Transform3D] = []
    var lote: int = 0
    for px in [-29.0, -11.0, 11.0, 29.0]:
        for pz in [-23.0, 23.0]:
            var casa: bool = ((lote + ix * 3 + iz * 7) % 2 == 0)
            var largura: float = (10.5 if casa else 12.0)
            var fundo: float = (12.5 if casa else 14.0)
            var altura: float = (4.6 + float((abs(ix + iz + lote) % 3)) * 0.5) if casa else (13.0 + float((abs(ix * 5 + iz * 3 + lote) % 4)) * 3.2)
            var pos := Vector3(px, 0.0, pz)
            var corpo := StaticBody3D.new()
            corpo.name = "Casa_%d" % lote if casa else "Predio_%d" % lote
            corpo.position = pos
            corpo.collision_layer = 1
            corpo.collision_mask = 1
            bairro.add_child(corpo)
            var col := CollisionShape3D.new()
            var forma := BoxShape3D.new()
            forma.size = Vector3(largura, altura, fundo)
            col.shape = forma
            col.position = Vector3(0.0, altura * 0.5, 0.0)
            corpo.add_child(col)
            var parede := casas if casa else predios
            _registrar(parede, Vector3(px, altura * 0.5, pz), Vector3(largura, altura, fundo))
            _registrar(telhados, Vector3(px, altura + 0.14, pz), Vector3(largura + 0.7, 0.26, fundo + 0.7))
            _registrar(portas, Vector3(px, 1.08, pz - fundo * 0.5 - 0.045), Vector3(1.25, 2.16, 0.09))
            var andares: int = 2 if casa else int(floor((altura - 1.0) / 3.0))
            for andar in range(andares):
                var y: float = 2.7 + float(andar) * 3.0 if not casa else 2.55 + float(andar) * 1.65
                for coluna in [-1.0, 1.0]:
                    _registrar(janelas, Vector3(px + coluna * largura * 0.27, y, pz - fundo * 0.5 - 0.055), Vector3(1.05, 1.14 if not casa else 0.83, 0.09))
            lote += 1
    _multimalha(bairro, "Paredes_Casas", casa_parede, casas)
    _multimalha(bairro, "Paredes_Predios", predio_parede, predios)
    _multimalha(bairro, "Telhados", telha, telhados)
    _multimalha(bairro, "Janelas", vidro, janelas)
    _multimalha(bairro, "Portas", porta, portas)
