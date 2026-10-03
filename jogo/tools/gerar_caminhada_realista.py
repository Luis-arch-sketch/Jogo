# -*- coding: utf-8 -*-
"""
Regenera o clip 'walk' de assets/amber_motion_baked.json usando o modelo
biomecanico classico de caminhada humana (referencias: Murray et al. 1969,
Winter "Biomechanics and Motor Control of Human Movement" 2009, Perry 1992):

  - Quadril (sagital): +20 deg / -10 deg; pico de flexao no mid-swing (~70%),
    extensao maxima no toe-off (~50%).
  - Joelho: ~5 deg no contato inicial, ~15-18 deg em apoio medio, pico de
    ~40-45 deg no swing inicial (~73%) para clearance do pe.
  - Tornozelo: ~0/-5 deg dorsiflexado no calcanhar, +10/12 deg flexao plantar
    no toe-off, dorsiflexao novamente no swing.
  - Pelve: rotacao horizontal +-4 deg, inclinacao lateral +-3 deg e elevacao
    vertical com DOIS picos por ciclo (~4 cm p-p).
  - Tronco: contrarrotacao em relacao a pelve; bracos em balanço alternado
    contralateral (~+-18 deg) com cotovelos a ~25-30 deg.

Os angulos sao convertidos em quaternions locais na ordem usada pelo
esqueleto CC_Base (X = flexao/extensao sagital), respeitando simetria L/R.
"""
import json, math

FPS = 60
CYCLES = 2            # dois ciclos completos => loop suave (1 s por passo duplo... ver duration)
N = FPS * CYCLES + 1  # frames incluindo o ultimo igual ao primeiro

BONES = ['CC_Base_Hip','CC_Base_Spine01','CC_Base_Spine02','CC_Base_NeckTwist01',
         'CC_Base_L_Upperarm','CC_Base_R_Upperarm','CC_Base_L_Forearm','CC_Base_R_Forearm',
         'CC_Base_L_Hand','CC_Base_R_Hand','CC_Base_L_Thigh','CC_Base_R_Thigh',
         'CC_Base_L_Calf','CC_Base_R_Calf','CC_Base_L_Foot','CC_Base_R_Foot',
         'CC_Base_L_ToeBase','CC_Base_R_ToeBase']
IDX = {b: i for i, b in enumerate(BONES)}


def interp_curve(t, keys):
    """keys: lista ordenada circular (fase 0..1, valor em graus)."""
    # remove chave duplicada em t=1.0 (curva circular: 0 == 1)
    keys = [k for k in keys if not (k[0] == 1.0 and k[1] == keys[0][1])]
    ts = [k[0] for k in keys]
    vs = [k[1] for k in keys]
    t %= 1.0
    if t <= ts[0] or t >= ts[-1]:
        span = (1.0 - ts[-1]) + ts[0]
        d = (t - ts[-1]) % 1.0
        return vs[-1] + (vs[0] - vs[-1]) * (d / span)
    for i in range(len(ts) - 1):
        if ts[i] <= t <= ts[i + 1]:
            f = (t - ts[i]) / (ts[i + 1] - ts[i])
            f = f * f * (3 - 2 * f)  # suavizacao entre chaves
            return vs[i] + (vs[i + 1] - vs[i]) * f
    return vs[0]


# Curvas classicas de caminhada (fase do ciclo -> graus, plano sagital)
QUADIL   = [(0.00, 20), (0.15, 12), (0.31, 5), (0.50, -8),
            (0.62, 10), (0.75, 22), (0.85, 25), (1.00, 20)]
JOELHO   = [(0.00, 5), (0.15, 15), (0.31, 18), (0.50, 40),
            (0.62, 45), (0.73, 20), (0.85, 5), (1.00, 5)]
TORNOZ   = [(0.00, -5), (0.15, 0), (0.31, 8), (0.50, 12),
            (0.62, -2), (0.75, -8), (0.85, -6), (1.00, -5)]
PONTA    = [(0.00, 0), (0.31, 5), (0.50, 25), (0.62, 5), (0.75, -5), (1.00, 0)]
BRACO    = [(0.00, -18), (0.25, 0), (0.50, 18), (0.75, 0), (1.00, -18)]
COTOVELO = [(0.00, 25), (0.25, 32), (0.50, 22), (0.75, 28), (1.00, 25)]


def mul(a, b):
    aw, ax, ay, az = a
    bw, bx, by, bz = b
    return (aw*bw - ax*bx - ay*by - az*bz,
            aw*bx + ax*bw + ay*bz - az*by,
            aw*by - ax*bz + ay*bw + az*bx,
            aw*bz + ax*by - ay*bx + az*bw)


def quat(x_deg=0.0, y_deg=0.0, z_deg=0.0):
    cx, sx = math.sin(math.radians(x_deg)/2), math.cos(math.radians(x_deg)/2)
    cy, sy = math.sin(math.radians(y_deg)/2), math.cos(math.radians(y_deg)/2)
    cz, sz = math.sin(math.radians(z_deg)/2), math.cos(math.radians(z_deg)/2)
    w, x, y, z = mul(mul((cy, 0, sy, 0), (cx, sx, 0, 0)), (cz, 0, 0, sz))
    n = math.sqrt(w*w + x*x + y*y + z*z)
    return [round(x/n, 5), round(y/n, 5), round(z/n, 5), round(w/n, 5)]


frames = []
for i in range(N):
    t = (i / FPS) / CYCLES  # fase do ciclo 0..1
    pose = [[0.0, 0.0, 0.0, 1.0] for _ in BONES]

    q_l = interp_curve(t, QUADIL)
    q_r = interp_curve((t + 0.5) % 1.0, QUADIL)
    k_l = interp_curve(t, JOELHO);  k_r = interp_curve((t + 0.5) % 1.0, JOELHO)
    a_l = interp_curve(t, TORNOZ);  a_r = interp_curve((t + 0.5) % 1.0, TORNOZ)
    p_l = interp_curve(t, PONTA);   p_r = interp_curve((t + 0.5) % 1.0, PONTA)

    # Pernas: quadril flexiona para frente; canela flexiona para tras;
    # tornozelo compensa; ponta empurra no toe-off.
    pose[IDX['CC_Base_L_Thigh']] = quat(q_l)
    pose[IDX['CC_Base_R_Thigh']] = quat(q_r)
    pose[IDX['CC_Base_L_Calf']] = quat(k_l)
    pose[IDX['CC_Base_R_Calf']] = quat(k_r)
    pose[IDX['CC_Base_L_Foot']] = quat(a_l)
    pose[IDX['CC_Base_R_Foot']] = quat(a_r)
    pose[IDX['CC_Base_L_ToeBase']] = quat(p_l)
    pose[IDX['CC_Base_R_ToeBase']] = quat(p_r)

    # Pelve: rotacao horizontal +-4 deg, inclinacao lateral +-3 deg
    yaw = 4.0 * math.sin(2 * math.pi * t)
    roll = 3.0 * math.sin(2 * math.pi * t + math.pi)
    pose[IDX['CC_Base_Hip']] = quat(0.0, yaw, roll)

    # Tronco: leve inclinacao anterior + contrarrotacao da pelve
    pose[IDX['CC_Base_Spine01']] = quat(2.0, -yaw * 0.5)
    pose[IDX['CC_Base_Spine02']] = quat(0.5, -yaw * 0.4)
    pose[IDX['CC_Base_NeckTwist01']] = quat(-1.0, yaw * 0.6)

    # Bracos contralaterais as pernas
    bl = interp_curve((t + 0.5) % 1.0, BRACO)
    br = interp_curve(t, BRACO)
    cl = interp_curve((t + 0.5) % 1.0, COTOVELO)
    cr = interp_curve(t, COTOVELO)
    pose[IDX['CC_Base_L_Upperarm']] = quat(bl, 0, 5)
    pose[IDX['CC_Base_R_Upperarm']] = quat(br, 0, -5)
    pose[IDX['CC_Base_L_Forearm']] = quat(cl)
    pose[IDX['CC_Base_R_Forearm']] = quat(cr)

    frames.append(pose)

# Root offsets: elevacao vertical da pelve com dois picos por ciclo (~4 cm)
offsets = []
for i in range(N):
    t = (i / FPS) / CYCLES
    y = 0.02 + 0.02 * math.cos(4 * math.pi * t)
    offsets.append([0.0, round(y, 5), 0.0])

PATH = 'assets/amber_motion_baked.json'
d = json.load(open(PATH))
d['clips']['walk'] = {
    'duration': float(CYCLES),      # 2 s por ciclo completo (passo ~1.0 s, cadencia ~113 ppm)
    'stride_length': 1.44,          # distancia do ciclo completo (dois passos)
    'frames': frames,
    'root_offsets': offsets,
}
d['source'] = 'AmberCity: walk regenerada com curvas cinematicas classicas de caminhada humana (Murray/Winter/Perry)'
json.dump(d, open(PATH, 'w'), separators=(',', ':'))
print('walk regenerada:', len(frames), 'frames,', CYCLES, 's por ciclo completo')
