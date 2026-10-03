extends RefCounted
## IA emocional dos 120 moradores de AmberCity.
## Cada morador possui um estado interno com humor, energia, medo, dor e raiva
## que evolui sozinho (vagando pela cidade) e reage a estímulos externos
## (tiros/facadas = "ser_atingido"). A IA também escolhe MUITO RÁPIDO o que
## falar quando é atingida: reclamações ("porque você atirou em mim?"),
## súplicas ("ai meu Deus!"), gritos de dor e respostas conforme a emoção.

const NOMES: Array[String] = [
	"Ana", "Bruno", "Carla", "Diego", "Elena", "Fábio", "Gabi", "Hugo", "Íris", "João",
	"Karina", "Lucas", "Marina", "Nuno", "Olívia", "Pedro", "Rita", "Sérgio", "Tati", "Vitor",
	"Wesley", "Ximena", "Yara", "Zeca", "Alice", "Beto", "Cíntia", "Davi", "Eva", "Felipe",
]

# Reações imediatas à dor, por tipo de arma (a IA fala muito rápido ao levar tiro).
const DOR_TIRO: Array[String] = [
	"Por que você atirou em mim?! Ai meu Deus!",
	"AI! Por que atirou em mim?! Socorro!",
	"Ai meu Deus, estou sangrando! Porque você atirou?",
	"AUUU! Você atirou em mim! Que dor!",
	"Não! Por que me acertou?! Ai meu Deus, ai!",
	"Cai no chão... porque você atirou em mim?",
	"Socorro! Ela/ele atirou em mim! Ai!",
	"Que dor! Por que você fez isso comigo?!",
]
const DOR_CORPO: Array[String] = [
	"Ai! Por que você me bateu?!",
	"Para! Isso dói muito! Ai meu Deus!",
	"Você me cortou! Porque fez isso?!",
	"AU! Me deixa em paz!",
]
const GRITO_DOR: Array[String] = ["AAAAI!", "AI MEU DEUS!", "SOCORRO!", "ARGH!", "UI, QUE DOR!"]
const FUGA: Array[String] = [
	"Vou chamar a polícia!",
	"Corre, gente! Tem um louco atirando!",
	"Nunca mais passo nessa rua!",
	"Sai da frente, sai!",
]
const RAIVA: Array[String] = [
	"Seu covarde! Vai pagar por isso!",
	"Eu vou te denunciar, seu vândalo!",
	"Covarde! Só bate em quem está passeando!",
]
const SUPLICA: Array[String] = [
	"Por favor, não! Tenho filhos!",
	"Piedade! Estou sentindo muita dor!",
	"Não faz isso, pelo amor de Deus!",
	"Chega! Eu imploro, para!",
]
const NEUTRO: Array[String] = [
	"Que dia bonito pra caminhar...",
	"Esse café tá ótimo hoje.",
	"Só queria chegar em casa...",
	"A cidade tá movimentada.",
	"Hmm... preciso pagar as contas.",
	"Amo andar por essas ruas.",
]
const MEDO_AMBIENTE: Array[String] = [
	"Tiro na rua? Vou embora daqui!",
	"Que medo! Ouviram aquele estampido?",
	"Melhor eu ir pra casa agora.",
]

enum Humor { CALMO, FELIZ, TRISTE, NERVOSO }

var nome: String = ""
var humor: int = Humor.CALMO
var felicidade: float = 0.6     # 0..1
var energia: float = 0.8        # 0..1 (cai vagando; pede pausa)
var medo: float = 0.0           # 0..1
var dor: float = 0.0            # 0..1 (ao ser atingido sobe a 1)
var raiva: float = 0.0          # 0..1
var ferido: bool = false
var morrendo: bool = false
var morto: bool = false
var vida: float = 100.0
var ultimo_atirador: Node3D = null
var _tempo_fala: float = 0.0    # cooldown de fala (a IA responde em <0,4 s)
var _fala_atual: String = ""
var _tempo_exibicao: float = 0.0
var _rng := RandomNumberGenerator.new()
var _aceleracao_dor: float = 0.0  # usada pelo morador p/ animar a mão no ferimento

func _init(semente: int = 0) -> void:
	_rng.seed = semente + 7919
	nome = NOMES[_rng.randi_range(0, NOMES.size() - 1)]
	humor = _rng.randi_range(0, 3)
	felicidade = _rng.randf_range(0.45, 0.85)
	energia = _rng.randf_range(0.6, 0.95)

# ---------------- ciclo de vida emocional ----------------
func pensar(delta: float) -> void:
	if morto:
		return
	# Dor diminui devagar se ninguém mexer mais com a pessoa.
	dor = maxf(0.0, dor - delta * 0.02)
	# Medo e raiva esmorecem aos poucos.
	medo = maxf(0.0, medo - delta * 0.03)
	raiva = maxf(0.0, raiva - delta * 0.02)
	# Energia cai enquanto vaga; ela quer parar e descansar.
	energia = clampf(energia - delta * 0.004, 0.05, 1.0)
	if energia <= 0.1 and not ferido:
		energia = 0.75  # descansou durante a pausa
	# Humor acompanha a felicidade.
	if felicidade > 0.7:
		humor = Humor.FELIZ
	elif felicidade > 0.45:
		humor = Humor.CALMO
	elif felicidade > 0.25:
		humor = Humor.TRISTE
	else:
		humor = Humor.NERVOSO
	# Fala neutra ocasional (pensamentos altos), bem espaçada.
	_tempo_fala -= delta
	_tempo_exibicao -= delta
	if _tempo_exibicao <= 0.0:
		_fala_atual = ""
	if _tempo_fala <= 0.0 and not ferido:
		_tempo_fala = _rng.randf_range(18.0, 45.0)
		if medo > 0.5:
			_falar(_sortear(MEDO_AMBIENTE))
		elif _rng.randf() < 0.35:
			_falar(_sortear(NEUTRO))

# ---------------- estímulo: foi atingida ----------------
## `dano` vem da arma; `causador` é o nó do jogador. A IA decide na hora
## (resposta em fração de segundo) o que vai falar conforme suas emoções.
func ser_atingido(dano: float, causador: Node3D, corpo_a_corpo: bool = false) -> void:
	if morto:
		return
	vida -= dano
	dor = minf(1.0, dor + dano / 60.0)
	raiva = clampf(raiva + dano / 120.0, 0.0, 1.0)
	_medo_pela_agressao(dano)
	ultimo_atirador = causador
	ferido = true
	# Grito IMEDIATO de dor + frase decidida pela IA (muito rápido).
	_reagir_atingida(corpo_a_corpo)
	if vida <= 0.0:
		morto = true
		morrendo = false
		_falar("Aaaargh...")
		# Cai no chão: o morador trata o flag morto.

func _raiva_pelo_dano(): pass
func _medo_pela_agressao(dano: float) -> void:
	medo = clampf(medo + dano / 90.0, 0.0, 1.0)

func _reagir_atingida(corpo_a_corpo: bool) -> void:
	var pool_dor: Array[String] = DOR_CORPO if corpo_a_corpo else DOR_TIRO
	# 1) grito de dor instantâneo (às vezes já combinado com a pergunta).
	var grito: String = _sortear(GRITO_DOR)
	# 2) A IA ESCOLHE a fala conforme o estado emocional resultante:
	#    muita dor+medo -> súplica; raiva alta -> desaforo; padrão -> "por que
	#    você atirou em mim?".
	var escolha: String
	var sorteio: float = _rng.randf()
	if raiva > 0.7 and sorteio < 0.4:
		escolha = _sortear(RAIVA)
	elif medo > 0.75 and sorteio < 0.55:
		escolha = _sortear(SUPLICA)
	else:
		escolha = _sortear(pool_dor)
	# Frase composta falada MUITO RÁPIDO (aparece na balão ~instantaneamente).
	_falar(grito + " " + escolha)
	# Se a dor for grande, ainda berra um pedido de ajuda.
	if dor > 0.8:
		_falar_depois(_sortear(["Alguém me ajuda! Ai meu Deus!", "Está doendo demais! Ai!"]), 0.6)

var _fila_falas: Array[Dictionary] = []
func _falar(texto: String) -> void:
	_fala_atual = texto
	_tempo_exibicao = 3.2
	_tempo_fala = 6.0  # silêncio depois de reclamar

func _falar_depois(texto: String, atraso: float) -> void:
	_fila_falas.append({"texto": texto, "atraso": atraso})

func proxima_fala(delta: float) -> String:
	# Consome fila de frases encadeadas (a IA fala tudo bem rápido).
	for i in range(_fila_falas.size() - 1, -1, -1):
		var item: Dictionary = _fila_falas[i]
		item["atraso"] -= delta
		if item["atraso"] <= 0.0:
			_fila_falas.remove_at(i)
			_falar(String(item["texto"]))
	if _tempo_exibicao > 0.0:
		return _fala_atual
	return ""

# Utilidades -------------------------------------------------
func _sortear(pool: Array[String]) -> String:
	return pool[_rng.randi_range(0, pool.size() - 1)]

## Decide se este morador foge ao ver alguém atirar perto (contágio de pânico).
func entrar_em_panico(origem: Vector3) -> void:
	medo = clampf(medo + 0.5, 0.0, 1.0)
	if _rng.randf() < 0.6:
		_falar(_sortear(FUGA))

func deve_fugir() -> bool:
	return medo > 0.6 or dor > 0.75
