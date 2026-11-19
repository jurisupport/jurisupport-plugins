// 조각 애니메이션 렌더 엔진. 모든 프레임은 시간 t의 순수 함수다. window.seek(t)로 그린다.
// 장면 정의는 timeline.json(timeline.py가 scene.json의 어절 앵커를 초로 바꾼 것)에서 읽는다.
// 좌표: 배경(플레이트) 그림 좌표 1152×2048. 화면은 1080×1920.
const CW = 1080, CH = 1920, PW = 1152, PH = 2048, K = CW / PW;
const INK = '#2b2d42', RED = '#d62828', ORANGE = '#f4a261', CHALK = '#f4f1e8', TEAL = '#2a9d8f';
let KR = '"Pretendard","Apple SD Gothic Neo","Malgun Gothic","Noto Sans CJK KR","Noto Sans KR",sans-serif';
let EN = KR;
let TL, META, IMG = {}, cv, ctx, NOW = 0, PREV = -1;
// 효과음 시각 기록: COLLECT 모드에서 이전 프레임과 지금 프레임 사이에 시작한 이벤트를 모은다
window.EV = []; const EVK = new Set();
function ev(type, t0) { if (window.COLLECT && t0 > PREV && t0 <= NOW) { const k = type + t0.toFixed(3); if (!EVK.has(k)) { EVK.add(k); window.EV.push({ type, t: +t0.toFixed(3) }); } } }

// ---------- 공용 수학 ----------
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const ease = p => 1 - Math.pow(1 - clamp(p, 0, 1), 3);
const spring = t => t <= 0 ? 0 : 1 - Math.exp(-7 * t) * Math.cos(16 * t);
const squash = t => t <= 0 ? 1 : 1 + 0.14 * Math.exp(-6 * t) * Math.sin(20 * t);
function hash(n) { const x = Math.sin(n * 127.1 + 311.7) * 43758.5453; return x - Math.floor(x); }
const T = (v, d = -1) => (typeof v === 'number' ? v : d);   // 시각 값이 없으면 처음부터 보인다

// ---------- 카메라 ----------
// 플레이트와 그 위 모든 요소를 같은 변환 안에서 그린다. 카메라는 플레이트 안으로 제한한다.
let CAM = { s: K, tx: 0, ty: 0 };
function camera(t, sh, o = {}) {
  const u = clamp((t - sh.start) / Math.max(0.5, sh.end - sh.start), 0, 1);
  const z0 = o.z || 1.04, z1 = z0 * (1 + (o.drift ?? 0.03));
  const z = z0 + (z1 - z0) * u;
  let fx = o.fx ?? PW / 2, fy = o.fy ?? PH / 2;
  if (o.focus === 'board' && sh.plate && META.plates[sh.plate]) { const r = META.plates[sh.plate].rect; fx = r[0] + r[2] / 2; fy = r[1] + r[3] / 2 + (o.dy || 0); }
  fx += (o.panX || 0) * (u - 0.5); fy += (o.panY || 0) * (u - 0.5);
  const s = K * z;
  let tx = CW / 2 - fx * s, ty = CH / 2 - fy * s;
  tx = clamp(tx, CW - PW * s, 0); ty = clamp(ty, CH - PH * s, 0);
  CAM = { s, tx, ty };
  ctx.setTransform(s, 0, 0, s, tx, ty);
}
function plate(name) { ctx.drawImage(IMG['plate_' + name], 0, 0, PW, PH); }
function rectOf(name) { return META.plates[name].rect; }   // [x,y,w,h] 플레이트 좌표

// ---------- 등장 효과: 스프링·스쿼시·흰 퍼프 (페이드 없음) ----------
function puff(x, y, t0, t, r = 60) {
  const d = t - t0; if (d < 0 || d > 0.4) return;
  const p = d / 0.4;
  ctx.save(); ctx.fillStyle = '#fff';
  for (let i = 0; i < 7; i++) {
    const a = i / 7 * Math.PI * 2 + 0.4;
    const rr_ = r * (0.5 + 1.3 * ease(p)), cr = r * 0.32 * (1 - p);
    ctx.beginPath(); ctx.arc(x + Math.cos(a) * rr_, y + Math.sin(a) * rr_, Math.max(0, cr), 0, 7); ctx.fill();
  }
  ctx.restore();
}
function popIn(t0, t, x, y, draw, r = 60) {
  ev('pop', t0); if (t < t0) return;
  const d = t - t0, s = spring(d * 1.0), q = squash(d);
  ctx.save(); ctx.translate(x, y); ctx.scale(s * q, s / q); draw(); ctx.restore();
  puff(x, y, t0, t, r);
}

// ---------- 글자: 세계 안 사물 위에서만 타이핑 ----------
// 초당 cps글자. 각 글자는 1.45배 크기로 0.7em 오른쪽에서 나타나 0.18초 동안 자리 잡는다.
function typed(text, x, y, size, t0, t, o = {}) {
  if (t < t0) return 0;
  const cps = o.cps || 10, font = (o.en ? EN : KR);
  ctx.save(); ctx.font = `800 ${size}px ${font}`; ctx.fillStyle = o.color || INK; ctx.textBaseline = 'middle';
  const chars = [...text]; const ws = chars.map(c => ctx.measureText(c).width); const total = ws.reduce((a, b) => a + b, 0);
  let cx = o.align === 'left' ? x : x - total / 2; let shown = 0;
  chars.forEach((c, i) => {
    const ti = t0 + i / cps; if (c.trim()) ev('tick', ti); if (t < ti) { cx += ws[i]; return; }
    const p = ease((t - ti) / 0.18), sc = 1.45 - 0.45 * p, dx = 0.7 * size * (1 - p);
    ctx.save(); ctx.translate(cx + ws[i] / 2 + dx, y); ctx.scale(sc, sc); ctx.textAlign = 'center'; ctx.fillText(c, 0, 0); ctx.restore();
    cx += ws[i]; shown++;
  });
  ctx.restore(); return shown;
}
function fitSize(text, maxW, size, en) { ctx.save(); ctx.font = `800 ${size}px ${en ? EN : KR}`; const w = ctx.measureText(text).width; ctx.restore(); return w > maxW ? size * maxW / w : size; }
// 보드 사각형 안에 여러 줄을 맞춰 쓴다
function board(name, lines, t, o = {}) {
  const [x, y, w, h] = rectOf(name); const dark = META.plates[name].dark;
  const color = o.color || (dark ? CHALK : INK); const n = lines.length; const pad = w * 0.08;
  let size = Math.min(h / (n + 0.6), o.max || 140);
  lines.forEach(L => { size = Math.min(size, fitSize(L.text, w - pad * 2, (L.scale || 1) * size, L.en) / (L.scale || 1)); });
  lines.forEach((L, i) => {
    const ly = y + h * (i + 1) / (n + 1);
    typed(L.text, x + w / 2, ly, (L.scale || 1) * size, T(L.t), t, { color: L.color === 'red' ? RED : (L.color || color), en: L.en, cps: L.cps });
  });
  return { x, y, w, h, size };
}
// 보드 안 비율 좌표(0~1)를 플레이트 좌표로 바꾼다. in:'board'가 아니면 x,y를 그대로 쓴다.
function place(sh, o) {
  if (o.in === 'board' && sh.plate && META.plates[sh.plate]) { const [x, y, w, h] = rectOf(sh.plate); return [x + w * (o.fx ?? 0.5), y + h * (o.fy ?? 0.5), Math.min(w, h)]; }
  if (sh.headline) return [(o.fx ?? 0.5) * PW, (o.fy ?? 0.5) * PH, 600];
  return [o.x ?? PW / 2, o.y ?? PH / 2, 400];
}

// ---------- 빨간 X·체크 ----------
function redX(cx, cy, r, t0, t) {
  ev('hit', t0); if (t < t0) return;
  ctx.save(); ctx.strokeStyle = RED; ctx.lineCap = 'round'; ctx.lineWidth = 30 / CAM.s;
  const p1 = clamp((t - t0) / 0.11, 0, 1), p2 = clamp((t - t0 - 0.11) / 0.11, 0, 1);
  ctx.beginPath(); ctx.moveTo(cx - r, cy - r); ctx.lineTo(cx - r + 2 * r * p1, cy - r + 2 * r * p1); ctx.stroke();
  if (p2 > 0) { ctx.beginPath(); ctx.moveTo(cx + r, cy - r); ctx.lineTo(cx + r - 2 * r * p2, cy - r + 2 * r * p2); ctx.stroke(); }
  ctx.restore();
}
function check(cx, cy, r, t0, t) {
  ev('ding', t0); if (t < t0) return;
  ctx.save(); ctx.strokeStyle = TEAL; ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.lineWidth = 30 / CAM.s;
  const p = clamp((t - t0) / 0.22, 0, 1);
  const pts = [[cx - r, cy], [cx - r * 0.3, cy + r * 0.7], [cx + r, cy - r * 0.8]];
  ctx.beginPath(); ctx.moveTo(...pts[0]);
  if (p < 0.4) { const q = p / 0.4; ctx.lineTo(pts[0][0] + (pts[1][0] - pts[0][0]) * q, pts[0][1] + (pts[1][1] - pts[0][1]) * q); }
  else { const q = (p - 0.4) / 0.6; ctx.lineTo(...pts[1]); ctx.lineTo(pts[1][0] + (pts[2][0] - pts[1][0]) * q, pts[1][1] + (pts[2][1] - pts[1][1]) * q); }
  ctx.stroke(); ctx.restore();
}

// ---------- 날짜 카드: 흰 카드, 왼쪽 위 주황 달력. 글자 폭을 재서 카드 폭을 늘린다 ----------
function dateCard(x, y, text, t0, t) {
  popIn(t0, t, x, y, () => {
    ctx.save(); ctx.font = `800 50px ${EN}`; const tw = ctx.measureText(text).width; ctx.restore();
    const h = 120 / K, w = Math.max(330 / K, 16 + 56 + 22 + tw + 30);
    ctx.fillStyle = '#fff'; rr(-w / 2, -h / 2, w, h, 18); ctx.fill();
    ctx.fillStyle = ORANGE; rr(-w / 2 + 16, -h / 2 + 16, 56, 52, 8); ctx.fill();
    ctx.fillStyle = '#fff'; ctx.fillRect(-w / 2 + 22, -h / 2 + 32, 44, 30);
    ctx.fillStyle = ORANGE; ctx.fillRect(-w / 2 + 28, -h / 2 + 8, 8, 16); ctx.fillRect(-w / 2 + 52, -h / 2 + 8, 8, 16);
    typed(text, -w / 2 + 16 + 56 + 22, 6, 50, t0 + 0.12, t, { en: true, cps: 30, align: 'left' });
  }, 90);
}
function rr(x, y, w, h, r) { ctx.beginPath(); ctx.moveTo(x + r, y); ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r); ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath(); }

// ---------- 캐릭터 ----------
// 몸통 → 팔(IK) → 머리(끄덕임·깜빡임) 순서로 그린다.
function blinkOn(t, seed) {
  let c = hash(seed) * 2.0, i = 0;
  while (c < t + 1) { const iv = 2.7 + hash(seed * 7 + i) * 1.5; if (t >= c && t < c + 0.14) return true; c += iv; i++; }
  return false;
}
function ik(sx, sy, tx, ty, L1, L2, bend) {
  let dx = tx - sx, dy = ty - sy, d = Math.hypot(dx, dy); d = clamp(d, Math.abs(L1 - L2) + 1, L1 + L2 - 0.5);
  const a = Math.atan2(dy, dx), cosA = (L1 * L1 + d * d - L2 * L2) / (2 * L1 * d), A = Math.acos(clamp(cosA, -1, 1));
  const ua = a - bend * A, ex = sx + Math.cos(ua) * L1, ey = sy + Math.sin(ua) * L1;
  const la = Math.atan2(sy + Math.sin(a) * d - ey, sx + Math.cos(a) * d - ex);
  return { ex, ey, hx: ex + Math.cos(la) * L2, hy: ey + Math.sin(la) * L2, la };
}
function hand(x, y, ang, pose, r, skin) {
  ctx.save(); ctx.translate(x, y); ctx.rotate(ang); ctx.fillStyle = skin;
  if (pose === 'fist') { ctx.beginPath(); ctx.arc(0, 0, r * 0.95, 0, 7); ctx.fill(); }
  else if (pose === 'point') { ctx.beginPath(); ctx.ellipse(0, 0, r * 0.95, r * 0.8, 0, 0, 7); ctx.fill(); rr(r * 0.4, -r * 0.28, r * 1.3, r * 0.56, r * 0.28); ctx.fill(); }
  else { ctx.beginPath(); ctx.ellipse(r * 0.25, 0, r * 1.25, r * 0.9, 0, 0, 7); ctx.fill(); ctx.beginPath(); ctx.ellipse(-r * 0.1, -r * 0.85, r * 0.42, r * 0.32, -0.6, 0, 7); ctx.fill(); }
  ctx.restore();
}
// 팔 하나: 918px 스프라이트 기준 상완 118, 하완 112. 어깨 기준 각도 a(도; 0=아래, +=바깥, -=몸 앞)와 뻗는 정도 r.
// 몸 뒤에 그리는 팔은 손·팔꿈치가 몸 윤곽 바깥에 나오도록 각도를 자동으로 벌린다.
function edgeAt(m, out, y) { const e = m.edge; if (!e) return null; const i = clamp(Math.round(y / e.step), 0, e.xl.length - 1); const v = out < 0 ? e.xl[i] : e.xr[i]; return v < 0 ? null : v; }
function drawArm(m, A) {
  const u = m.h / 918, L1 = 118 * u, L2 = 112 * u, th = 36 * u * 1.35, base = m.sleeve || m.cloth;
  const sleeve = `rgb(${base.map(c => Math.round(c * 0.88))})`, cuff = `rgb(${base.map(c => Math.round(c * 0.74))})`;
  // 내린 팔(a<30)은 거의 곧게 펴고, 손짓(30<=a<100)은 살짝만 굽혀 비스듬히 내민다
  const a0 = A.a ?? 12, out = A.side === 0 ? -1 : 1, R = (L1 + L2) * (a0 < 30 && !A.front ? 0.985 : (a0 >= 30 && a0 < 100 ? Math.max(A.r ?? 0.9, 0.93) : clamp(A.r ?? 0.9, 0.35, 0.99)));
  let [sx, sy] = m.sockets[A.side];
  const frontArm = A.front || a0 >= 30;
  // 어깨 소켓: 측정한 어깨 윗선의 바깥 모서리에서 팔 두께 절반만큼 안쪽·아래 (팔 윗면이 어깨 윗선과 맞닿는다)
  if (m.shoulder) { const [ty, xl, xr] = m.shoulder; sx = (out < 0 ? xl : xr) - out * th * 0.5; sy = ty + th * 0.5; }
  let a = a0, j;
  for (let k = 0; k < 60; k++) {
    const ar = a * Math.PI / 180, tx = sx + Math.sin(ar) * R * out, ty = sy + Math.cos(ar) * R;
    const j1 = ik(sx, sy, tx, ty, L1, L2, 1), j2 = ik(sx, sy, tx, ty, L1, L2, -1);
    // 팔꿈치는 몸 바깥쪽으로 굽힌다(머리 위로 든 자세 a>=140만 아래로)
    j = (a >= 140) ? (j1.ey >= j2.ey ? j1 : j2) : (out * j1.ex >= out * j2.ex ? j1 : j2);
    if (A.front || a >= 100) break;
    const eh = edgeAt(m, out, j.hy), ee = edgeAt(m, out, j.ey);
    const okH = eh == null || out * (j.hx - eh) >= th * 0.1, okE = ee == null || out * (j.ex - ee) >= th * 0.28;
    if (okH && okE) break; a += 1.5;
  }
  ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.strokeStyle = sleeve; ctx.lineWidth = th;
  ctx.beginPath(); ctx.moveTo(sx, sy); ctx.lineTo(j.ex, j.ey); ctx.lineTo(j.hx, j.hy); ctx.stroke();
  const cx = j.hx - Math.cos(j.la) * th * 0.35, cy = j.hy - Math.sin(j.la) * th * 0.35;
  ctx.strokeStyle = cuff; ctx.lineCap = 'butt'; ctx.beginPath(); ctx.moveTo(cx - Math.cos(j.la) * th * 0.25, cy - Math.sin(j.la) * th * 0.25); ctx.lineTo(cx, cy); ctx.stroke();
  if (frontArm) { ctx.fillStyle = sleeve; ctx.beginPath(); ctx.arc(sx, sy, th * 0.58, 0, 7); ctx.fill(); }   // 어깨 캡: 몸 앞 팔이 어깨에서 시작하게
  hand(j.hx, j.hy, j.la, A.pose || 'open', th * 0.5, `rgb(${m.skin})`);
  if (A.held) A.held(j.hx, j.hy, th);
}
// 이름 붙은 팔 자세. side 0 = 그림 왼쪽 팔, side 1 = 그림 오른쪽 팔.
const DOWN = s => ({ side: s, a: 12, r: 0.92, pose: 'open' });
const POSES = {
  down: t => [DOWN(0), DOWN(1)],
  fists: t => [{ side: 0, a: 6, r: 0.85, pose: 'fist' }, { side: 1, a: 6, r: 0.85, pose: 'fist' }],
  talk: t => { const g = Math.sin(t * 6) * 14; return [{ side: 0, a: 62 + g, r: 0.72, pose: 'open' }, DOWN(1)]; },
  explain: t => { const g = Math.sin(t * 5) * 14; return [{ side: 0, a: 62 + g, r: 0.7, pose: 'open' }, { side: 1, a: 62 - g, r: 0.7, pose: 'open' }]; },
  shrug: t => [{ side: 0, a: 55, r: 0.62, pose: 'open' }, { side: 1, a: 55, r: 0.62, pose: 'open' }],
  point_left: t => [{ side: 0, a: 112, r: 0.97, pose: 'point' }, DOWN(1)],
  point_right: t => [DOWN(0), { side: 1, a: 112, r: 0.97, pose: 'point' }],
  point_up_left: t => [{ side: 0, a: 128, r: 0.97, pose: 'point' }, DOWN(1)],
  point_up_right: t => [DOWN(0), { side: 1, a: 128, r: 0.97, pose: 'point' }],
  raise_left: t => [{ side: 0, a: 150, r: 0.95, pose: 'open' }, DOWN(1)],
  raise_right: t => [DOWN(0), { side: 1, a: 150, r: 0.95, pose: 'open' }],
  cheer: t => [{ side: 0, a: 140, r: 0.9, pose: 'open' }, { side: 1, a: 150, r: 0.95, pose: 'fist' }],
  angry: t => { const s = Math.sin(t * 30) * 5; return [{ side: 0, a: 150 + s, r: 0.75, pose: 'fist' }, { side: 1, a: 150 - s, r: 0.75, pose: 'fist' }]; },
  hold: t => [DOWN(0), { side: 1, front: true, a: -35, r: 0.55, pose: 'fist' }],
};
// 한 장면 안에서 시각에 따라 자세를 바꾼다: c.pose(처음) → c.poses[{t, pose}]
function poseAt(c, t) { let p = c.pose || 'down'; (c.poses || []).forEach(q => { if (t >= T(q.t, 1e9)) p = q.pose; }); return p; }
function charOf(c, t) {
  const m = META.chars[c.name]; if (!m) return;
  const pn = poseAt(c, t), arms = (m.sockets && POSES[pn]) ? POSES[pn](t) : [];
  if (c.hold && arms.length) {   // 든 물건은 오른쪽 손(hold 자세) 또는 마지막 팔에 붙인다
    const A = arms[arms.length - 1];
    A.held = (hx, hy) => { ctx.save(); ctx.translate(hx, hy - 60); ICON[c.hold] && ICON[c.hold](70); ctx.restore(); };
  }
  char(c.name, c.x ?? PW / 2, c.y ?? 2030, t, {
    h: c.h || 1100, seed: c.seed, talk: c.talk, nod: c.nod, arms,
    flip: c.flip ? !(t > T(c.flip_t, 1e9)) : (t > T(c.flip_t, 1e9)), react: T(c.react_t, c.flip_t ?? undefined), jump: c.jump_t, t0: c.enter_t,
  });
  if (c.bang_t != null) bang((c.x ?? PW / 2) + (c.bang_dx ?? 240), (c.y ?? 2030) - (c.h || 1100) * 0.95, c.bang_t, t, c.bang || '!');
}
// o: {h:키(월드px), flip, nod, talk, arms, jump, t0(등장), react}
function char(name, x, y, t, o = {}) {
  const m = META.chars[name], h = o.h || 1100, s = h / m.h, seed = o.seed || name.length * 13;
  const enter = o.t0 != null ? o.t0 : -9;
  if (t < enter) return;
  if (o.t0 != null) ev('pop', o.t0);
  const de = t - enter, sp = o.t0 != null ? spring(de) : 1;
  // 뒤돌기·반응은 크기를 0으로 되돌리지 않고 스쿼시만 준다
  const q = o.t0 != null && de < 1.5 ? squash(de) : (o.react != null && t > o.react ? squash(t - o.react) : 1);
  const jumpY = o.jump != null && t > o.jump ? -Math.max(0, Math.sin(clamp((t - o.jump) / 0.45, 0, 1) * Math.PI)) * h * 0.12 : 0;
  const breath = 1 + 0.008 * Math.sin(t * 2.4 + seed);
  ctx.save(); ctx.translate(x, y + jumpY); ctx.scale((o.flip ? -1 : 1) * sp * q, sp / q * breath); ctx.scale(s, s);
  ctx.translate(-m.w / 2, -m.h);
  // 내린 팔(a<30)은 몸 뒤, 든 팔·손짓·몸 앞 팔은 몸 앞에 그린다(어깨에서 바로 시작하는 게 보이도록)
  const arms = o.arms || [];
  const isFront = A => A.front || (A.a ?? 12) >= 30;
  arms.filter(A => !isFront(A)).forEach(A => drawArm(m, A));
  ctx.drawImage(IMG[name + '_body'], 0, 0);
  arms.filter(isFront).forEach(A => drawArm(m, A));
  // 머리: 목을 축으로 ±0.035rad 끄덕임, 말할 때 더 크게
  const nod = (o.nod ?? 1) * 0.035 * Math.sin(t * (o.talk ? 7.5 : 2.2) + seed);
  ctx.translate(m.neckx, m.neck); ctx.rotate(nod); ctx.translate(-m.neckx, -m.neck);
  ctx.drawImage(IMG[name + '_head'], 0, 0);
  if (m.eyes.length && blinkOn(t, seed)) {
    ctx.fillStyle = `rgb(${m.skin})`;
    m.eyes.forEach(([ex, ey, r]) => { ctx.beginPath(); ctx.ellipse(ex, ey, r * 0.75, r * 0.75, 0, 0, 7); ctx.fill(); ctx.fillStyle = '#1e1e28'; ctx.fillRect(ex - r * 0.6, ey - 3, r * 1.2, 6); ctx.fillStyle = `rgb(${m.skin})`; });
  }
  ctx.restore();
}
function bang(x, y, t0, t, txt = '!', size = 120) { popIn(t0, t, x, y, () => { ctx.fillStyle = RED; ctx.font = `800 ${size}px ${EN}`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText(txt, 0, 0); }, 50); }

// ---------- 아이콘(코드로 그린다. 놓일 보드 색과 대비되는 색을 고른다) ----------
const ICON = {
  bill(s) { ctx.fillStyle = '#e8d9c0'; rr(-s, -s * 0.55, s * 2, s * 1.1, 10); ctx.fill(); ctx.fillStyle = '#5e8c8a'; ctx.beginPath(); ctx.arc(0, 0, s * 0.35, 0, 7); ctx.fill(); },
  bars(s) { ctx.fillStyle = '#2e3a59'; rr(-s, -s, s * 2, s * 2, 12); ctx.fill(); ctx.fillStyle = '#9aa9b8'; rr(-s * 0.8, -s * 0.8, s * 1.6, s * 1.6, 6); ctx.fill(); ctx.fillStyle = '#2e3a59'; for (let i = -2; i <= 2; i++) ctx.fillRect(i * s * 0.32 - s * 0.07, -s * 0.8, s * 0.14, s * 1.6); },
  lock(s) { ctx.strokeStyle = '#2e3a59'; ctx.lineWidth = s * 0.22; ctx.beginPath(); ctx.arc(0, -s * 0.25, s * 0.5, Math.PI, 0); ctx.stroke(); ctx.fillStyle = '#9c8dc1'; rr(-s * 0.8, -s * 0.25, s * 1.6, s * 1.2, 12); ctx.fill(); ctx.fillStyle = '#2e3a59'; ctx.beginPath(); ctx.arc(0, s * 0.3, s * 0.15, 0, 7); ctx.fill(); },
  poster(s) { ctx.fillStyle = '#fff'; ctx.fillRect(-s * 0.75, -s, s * 1.5, s * 2); ctx.fillStyle = '#9aa9b8'; for (let i = 0; i < 4; i++) ctx.fillRect(-s * 0.55, -s * 0.7 + i * s * 0.4, s * (i % 2 ? 0.8 : 1.1), s * 0.14); ctx.fillStyle = ORANGE; ctx.beginPath(); ctx.arc(0, -s * 1.02, s * 0.12, 0, 7); ctx.fill(); },
  document(s) { ICON.poster(s); },
  frame(s) { ctx.fillStyle = '#c9a66b'; ctx.fillRect(-s, -s * 0.8, s * 2, s * 1.6); ctx.fillStyle = '#e8d9c0'; ctx.fillRect(-s * 0.78, -s * 0.6, s * 1.56, s * 1.2); ctx.fillStyle = '#5e8c8a'; ctx.beginPath(); ctx.moveTo(-s * 0.7, s * 0.5); ctx.lineTo(-s * 0.1, -s * 0.2); ctx.lineTo(s * 0.7, s * 0.5); ctx.fill(); },
  podium(s) { ctx.fillStyle = '#e8d9c0'; ctx.beginPath(); ctx.moveTo(-s * 0.8, -s * 0.6); ctx.lineTo(s * 0.8, -s * 0.6); ctx.lineTo(s * 0.6, s); ctx.lineTo(-s * 0.6, s); ctx.fill(); ctx.fillStyle = '#2e3a59'; ctx.fillRect(-s * 0.05, -s * 1.1, s * 0.1, s * 0.5); ctx.beginPath(); ctx.arc(0, -s * 1.15, s * 0.14, 0, 7); ctx.fill(); },
  megaphone(s) { ctx.fillStyle = '#f4a261'; ctx.beginPath(); ctx.moveTo(-s * 0.55, -s * 0.3); ctx.lineTo(s * 0.75, -s * 0.85); ctx.lineTo(s * 0.75, s * 0.85); ctx.lineTo(-s * 0.55, s * 0.3); ctx.closePath(); ctx.fill(); ctx.fillStyle = '#e8d9c0'; rr(-s * 0.95, -s * 0.32, s * 0.45, s * 0.64, s * 0.12); ctx.fill(); ctx.fillRect(-s * 0.55, s * 0.25, s * 0.18, s * 0.55); ctx.strokeStyle = '#e8d9c0'; ctx.lineWidth = s * 0.12; ctx.lineCap = 'round'; for (let i = 1; i <= 2; i++) { ctx.beginPath(); ctx.arc(s * 0.75, 0, s * 0.35 * i, -0.6, 0.6); ctx.stroke(); } },
  phone(s) { ctx.fillStyle = '#2e3a59'; rr(-s * 0.55, -s, s * 1.1, s * 2, 14); ctx.fill(); ctx.fillStyle = '#e8eef5'; rr(-s * 0.45, -s * 0.85, s * 0.9, s * 1.7, 8); ctx.fill(); },
  bubble(s) { ctx.fillStyle = '#9c8dc1'; rr(-s, -s * 0.45, s * 2, s * 0.9, s * 0.3); ctx.fill(); ctx.beginPath(); ctx.moveTo(-s * 0.5, s * 0.4); ctx.lineTo(-s * 0.8, s * 0.8); ctx.lineTo(-s * 0.2, s * 0.4); ctx.fill(); ctx.fillStyle = '#fff'; for (let i = -1; i <= 1; i++) { ctx.beginPath(); ctx.arc(i * s * 0.45, 0, s * 0.12, 0, 7); ctx.fill(); } },
  house(s) { ctx.fillStyle = '#e8d9c0'; ctx.fillRect(-s * 0.8, -s * 0.2, s * 1.6, s * 1.2); ctx.fillStyle = '#d62828'; ctx.beginPath(); ctx.moveTo(-s, -s * 0.15); ctx.lineTo(0, -s); ctx.lineTo(s, -s * 0.15); ctx.fill(); ctx.fillStyle = '#5e8c8a'; ctx.fillRect(-s * 0.2, s * 0.35, s * 0.4, s * 0.65); },
  coin(s) { ctx.fillStyle = '#f4a261'; ctx.beginPath(); ctx.arc(0, 0, s, 0, 7); ctx.fill(); ctx.fillStyle = '#e09045'; ctx.beginPath(); ctx.arc(0, 0, s * 0.72, 0, 7); ctx.fill(); ctx.fillStyle = '#fff'; ctx.fillRect(-s * 0.1, -s * 0.45, s * 0.2, s * 0.9); },
  gavel(s) { ctx.save(); ctx.rotate(-0.6); ctx.fillStyle = '#8a5a3b'; rr(-s * 0.9, -s * 0.35, s * 1.1, s * 0.7, 10); ctx.fill(); ctx.fillStyle = '#a8754f'; ctx.fillRect(s * 0.15, -s * 0.1, s * 0.95, s * 0.2); ctx.restore(); ctx.fillStyle = '#2e3a59'; rr(-s * 0.9, s * 0.65, s * 1.8, s * 0.3, 8); ctx.fill(); },
  clock(s) { ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(0, 0, s, 0, 7); ctx.fill(); ctx.strokeStyle = '#2e3a59'; ctx.lineWidth = s * 0.14; ctx.stroke(); ctx.lineCap = 'round'; ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(0, -s * 0.6); ctx.moveTo(0, 0); ctx.lineTo(s * 0.45, s * 0.1); ctx.stroke(); },
  headset(s) { ctx.strokeStyle = '#2e3a59'; ctx.lineWidth = s * 0.18; ctx.beginPath(); ctx.arc(0, 0, s * 0.8, Math.PI * 1.05, Math.PI * 1.95); ctx.stroke(); ctx.fillStyle = '#2e3a59'; rr(-s * 1.0, -s * 0.15, s * 0.4, s * 0.6, 8); ctx.fill(); rr(s * 0.6, -s * 0.15, s * 0.4, s * 0.6, 8); ctx.fill(); },
};
function icon(kind, x, y, s, t0, t) { if (!ICON[kind]) return; popIn(t0, t, x, y, () => ICON[kind](s), s * 1.2); }

// ---------- 효과(fx) 하나 ----------
function drawFx(f, sh, t) {
  const [x, y, base] = place(sh, f), r = f.r || base * (f.in === 'board' ? 0.4 : 0.3), t0 = T(f.t, sh.start + 0.1);
  if (f.type === 'x') redX(x, y, r, t0, t);
  else if (f.type === 'check') check(x, y, r, t0, t);
  else if (f.type === 'bang') bang(x, y, t0, t, f.text || '!', f.size || (sh.headline ? 280 : 120));
  else if (f.type === 'date') dateCard(x, y, f.text, t0, t);
  else if (f.type === 'icon') icon(f.icon, x, y, f.size || base * 0.18, t0, t);
  else if (f.type === 'text') typed(f.text, x, y, f.size || base * 0.18, t0, t, { cps: f.cps, color: f.color === 'red' ? RED : f.color, align: f.align });
  else if (f.type === 'neq') popIn(t0, t, x, y, () => { ctx.fillStyle = RED; ctx.font = `800 ${f.size || base * 0.24}px ${EN}`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText(f.text || '≠', 0, 0); }, 50);
  else if (f.type === 'count') {   // 숫자 카운터: 숫자 폭을 재서 단위를 붙이고 함께 가운데
    if (t < t0) return; ev('tick', t0);
    const t1 = T(f.until, t0 + 1.2), v = Math.round(ease((t - t0) / Math.max(0.3, t1 - t0)) * f.to);
    const sz = f.size || base * 0.3, ns = v.toLocaleString('en-US') + (v >= f.to && f.plus ? '+' : '');
    ctx.save(); ctx.textBaseline = 'middle'; ctx.fillStyle = f.color === 'red' ? RED : (f.color || INK);
    const fn = `800 ${sz}px ${EN}`, fk = `800 ${sz * 0.72}px ${KR}`; ctx.font = fn; const nw = ctx.measureText(f.to.toLocaleString('en-US') + (f.plus ? '+' : '')).width;
    ctx.font = fk; const kw = f.unit ? ctx.measureText(f.unit).width : 0; const gap = f.unit ? sz * 0.15 : 0, x0 = x - (nw + gap + kw) / 2;
    ctx.font = fn; ctx.textAlign = 'right'; ctx.fillText(ns, x0 + nw, y);
    if (f.unit) { ctx.font = fk; ctx.textAlign = 'left'; ctx.fillText(f.unit, x0 + nw + gap, y + sz * 0.05); }
    ctx.restore();
  }
}

// ---------- 헤드라인 화면(배경 그림 없이 단색 + 장식 + 큰 글자) ----------
function gear(cx, cy, r, ang, col) {
  ctx.save(); ctx.translate(cx, cy); ctx.rotate(ang); ctx.fillStyle = col;
  for (let i = 0; i < 10; i++) { ctx.save(); ctx.rotate(i / 10 * Math.PI * 2); ctx.fillRect(-r * 0.13, -r * 1.18, r * 0.26, r * 0.4); ctx.restore(); }
  ctx.beginPath(); ctx.arc(0, 0, r, 0, 7); ctx.fill(); ctx.fillStyle = 'rgba(0,0,0,0.18)'; ctx.beginPath(); ctx.arc(0, 0, r * 0.4, 0, 7); ctx.fill(); ctx.restore();
}
function shade(hex, f) { const n = parseInt(hex.slice(1), 16); return `rgb(${[16, 8, 0].map(s => Math.round(clamp(((n >> s) & 255) * f, 0, 255))).join(',')})`; }
function headline(t, sh) {
  const H = sh.headline; ctx.setTransform(1, 0, 0, 1, 0, 0);
  const u = (t - sh.start), z = 1.02 + 0.02 * u / Math.max(0.5, sh.end - sh.start);
  ctx.translate(CW / 2, CH / 2); ctx.scale(z, z); ctx.translate(-CW / 2, -CH / 2);
  const bg = H.bg || '#5b3fa6'; ctx.fillStyle = bg; ctx.fillRect(-60, -60, CW + 120, CH + 120);
  const deco = shade(bg, 1.18);
  if (H.deco === 'gears') { gear(880, 380, 150, u * 0.6, deco); gear(180, 1560, 210, -u * 0.45, deco); }
  else if (H.deco !== 'none') { ctx.fillStyle = deco; for (let i = 0; i < 9; i++) { const px = (hash(i) * CW + u * 40 * (1 + hash(i + 9))) % (CW + 200) - 100, py = hash(i + 3) * CH - u * 30; ctx.beginPath(); ctx.arc(px, py, 50 + hash(i + 5) * 70, 0, 7); ctx.arc(px + 60, py + 10, 40 + hash(i + 6) * 50, 0, 7); ctx.fill(); } }
  CAM = { s: 1, tx: 0, ty: 0 };
  const lines = Array.isArray(H.text) ? H.text : [H.text];
  lines.forEach((L, i) => { const size = Math.min(94, fitSize(L, CW * 0.84, 94)); typed(L, CW / 2, CH * 0.46 + (i - (lines.length - 1) / 2) * 130, size, T(H.t, sh.start + 0.05) + i * 0.5, t, { color: '#fff', cps: 11 }); });
  // 헤드라인 위 효과는 화면 좌표(비율)로 그린다
  ctx.save(); ctx.scale(K, K); (sh.fx || []).forEach(f => drawFx(f, sh, t)); ctx.restore();
}

// ---------- 끝 카드 ----------
function endCard(t, sh) {
  const E = TL.end_card || {}; ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.fillStyle = E.bg || '#2e3a59'; ctx.fillRect(0, 0, CW, CH); CAM = { s: 1, tx: 0, ty: 0 };
  if (E.title) typed(E.title, CW / 2, CH * 0.42, Math.min(84, fitSize(E.title, CW * 0.84, 84)), sh.start + 0.1, t, { color: '#fff', cps: 16 });
  (E.lines || []).forEach((L, i) => typed(L, CW / 2, CH * 0.52 + i * 70, Math.min(44, fitSize(L, CW * 0.86, 44)), sh.start + 0.4 + i * 0.3, t, { color: CHALK, cps: 30 }));
}

// ---------- 장면 하나 ----------
function drawShot(t, sh) {
  if (sh.end_card) return endCard(t, sh);
  if (sh.headline) return headline(t, sh);
  camera(t, sh, sh.camera || {}); plate(sh.plate);
  if (sh.board) board(sh.plate, sh.board.lines || [], t, sh.board);
  (sh.behind || []).forEach(c => charOf(c, t));         // 배경 앞, 가림막 뒤 캐릭터(판사석 뒤 판사 등)
  if (sh.cover) ctx.drawImage(IMG['plate_' + sh.plate], 0, sh.cover[0], PW, sh.cover[1] - sh.cover[0], 0, sh.cover[0], PW, sh.cover[1] - sh.cover[0]);
  (sh.fx || []).filter(f => f.under).forEach(f => drawFx(f, sh, t));
  (sh.chars || []).forEach(c => charOf(c, t));
  (sh.fx || []).filter(f => !f.under).forEach(f => drawFx(f, sh, t));
}

// ---------- 흰 스플랫 와이프(들어올 때 0.2초, 나갈 때 0.2초) ----------
function wipe(t) {
  TL.wipes.forEach(w => {
    ev('whoosh', w - 0.2);
    const d = t - w; if (d < -0.2 || d > 0.2) return;
    const p = d < 0 ? (d + 0.2) / 0.2 : 1 - d / 0.2;
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.fillStyle = '#fff'; ctx.beginPath();
    for (let i = 0; i < 9; i++) { const a = i / 9 * Math.PI * 2, R = 1300 * ease(p) * (0.75 + 0.35 * hash(i + w)); ctx.moveTo(CW / 2 + Math.cos(a) * R * 0.4, CH / 2 + Math.sin(a) * R * 0.4); ctx.arc(CW / 2 + Math.cos(a) * R * 0.4, CH / 2 + Math.sin(a) * R * 0.4, R * 0.75, 0, 7); }
    ctx.fill();
  });
}
// ---------- 맨 위 제목 띠, 하단 자막 ----------
function topTitle(t) {
  if (!TL.top_title) return; ctx.setTransform(1, 0, 0, 1, 0, 0);
  const s = Math.min(58, fitSize(TL.top_title, CW * 0.86, 58)); ctx.font = `800 ${s}px ${KR}`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  ctx.lineWidth = 12; ctx.strokeStyle = 'rgba(43,45,66,0.92)'; ctx.lineJoin = 'round'; ctx.strokeText(TL.top_title, CW / 2, 150); ctx.fillStyle = '#fff'; ctx.fillText(TL.top_title, CW / 2, 150);
}
function subs(t) {
  const s = TL.subs.find(s => t >= s.start - 0.05 && t < s.end + 0.15); if (!s) return;
  ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.font = `800 52px ${KR}`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  const words = s.text.split(' '), lines = [''];
  words.forEach(w => { const tryL = (lines[lines.length - 1] + ' ' + w).trim(); if (ctx.measureText(tryL).width > 900) lines.push(w); else lines[lines.length - 1] = tryL; });
  lines.forEach((L, i) => { const y = 1690 + (i - (lines.length - 1) / 2) * 68; ctx.lineWidth = 12; ctx.strokeStyle = 'rgba(43,45,66,0.92)'; ctx.lineJoin = 'round'; ctx.strokeText(L, CW / 2, y); ctx.fillStyle = '#fff'; ctx.fillText(L, CW / 2, y); });
}

// ---------- 진입점 ----------
function drawFrame(t) {
  t = Math.max(0, t); PREV = NOW; NOW = t;
  ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.fillStyle = '#9aa9b8'; ctx.fillRect(0, 0, CW, CH);
  const sh = TL.shots.find(s => t >= s.start && t < s.end) || TL.shots[TL.shots.length - 1];
  drawShot(t, sh); wipe(t);
  if (!sh.end_card) { topTitle(t); if (window.SUBS !== false) subs(t); }
}
// 모션 블러: 반 프레임 구간에 서브프레임 여러 장을 평균한다. 서브프레임 시각은 0 미만으로 내려가지 않는다.
let acc, actx;
window.seek = function (t, fps = 30, sub = 1) {
  if (sub <= 1) { drawFrame(t); return; }
  if (!acc) { acc = document.createElement('canvas'); acc.width = CW; acc.height = CH; actx = acc.getContext('2d'); }
  actx.clearRect(0, 0, CW, CH);
  for (let i = 0; i < sub; i++) { drawFrame(Math.max(0, t + (i / sub - 0.5) * (0.5 / fps))); actx.globalAlpha = 1 / (i + 1); actx.drawImage(cv, 0, 0); }
  ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.globalAlpha = 1; ctx.drawImage(acc, 0, 0);
};
async function boot() {
  cv = document.getElementById('c'); ctx = cv.getContext('2d');
  TL = await (await fetch('timeline.json')).json(); META = await (await fetch('assets/meta.json')).json();
  if (TL.font) { const f = new FontFace('SceneFont', `url(${TL.font})`); await f.load(); document.fonts.add(f); KR = '"SceneFont",' + KR; EN = KR; }
  const names = Object.keys(META.plates).map(k => ['plate_' + k, 'assets/plate_' + k + '.png']);
  Object.keys(META.chars).forEach(n => { names.push([n + '_body', 'assets/' + n + '_body.png'], [n + '_head', 'assets/' + n + '_head.png']); });
  await Promise.all(names.map(([k, src]) => new Promise((ok, no) => { const im = new Image(); im.onload = () => { IMG[k] = im; ok(); }; im.onerror = () => no('그림을 못 읽음: ' + src); im.src = src; })));
  await document.fonts.ready;
  window.DURATION = TL.duration; window.READY = true;
}
boot().catch(e => { window.ERR = String(e); });
