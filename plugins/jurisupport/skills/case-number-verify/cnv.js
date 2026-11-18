#!/usr/bin/env node
// 사법정보공개포털 「허위 사건번호 확인」 조회 도구.
// 자동입력방지 문자는 사람이 직접 읽어 넣는다. 이 스크립트는 캡차를 풀지 않는다.
//
// 사용법
//   node cnv.js start [--headed] [--out <dir>]   브라우저 세션 시작(백그라운드 유지)
//   node cnv.js check "<사건번호 문자열>"          사건번호를 넣고 캡차 이미지를 저장
//   node cnv.js answer <숫자6자리>                사람이 읽은 캡차로 검색하고 결과 기록
//   node cnv.js answer --browser                  사람이 브라우저 창에서 직접 입력·검색한 결과를 읽음(--headed 전용)
//   node cnv.js refresh                           캡차 새로고침
//   node cnv.js parse "<문자열>"                   사건번호 해석만 확인(브라우저 불필요)
//   node cnv.js status | stop

const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawn } = require('child_process');

const PORT = Number(process.env.CNV_PORT || 47321);
const URL_PAGE = 'https://portal.scourt.go.kr/pgp/index.on?m=PGP210M01&l=N&c=200';
const IDLE_MS = 20 * 60 * 1000;
const COURTS = require('./courts.json');

const SEL = {
  court: '#mf_mainFrame_sbx_cortCd',
  year: '#mf_mainFrame_ibx_dplPvsnAplyCsYr',
  type: '#mf_mainFrame_ibx_csDvsCdNm',
  serial: '#mf_mainFrame_ibx_csNoGnrnoSeq',
  branch: '#mf_mainFrame_ibx_csBrncNo',
  captchaImg: '#mf_mainFrame_img_captchaIrc',
  captchaInput: '#mf_mainFrame_ibx_captCha',
  search: '#mf_mainFrame_btn_search',
};

// ---------- 사건번호 해석 ----------

// 대법원 사건부호(court 표시가 없을 때 대법원으로 본다)
const SUPREME_TYPES = new Set(['다', '도', '두', '므', '스', '마', '그', '모', '추', '수', '우', '누', '다카', '도카',
  '재다', '재도', '재두', '재므', '재스', '재마', '재그', '재모', '재누']);

function normCourt(s) {
  return s.replace(/\s+/g, '')
    .replace(/고법/g, '고등법원').replace(/지법/g, '지방법원').replace(/가법/g, '가정법원')
    .replace(/행법/g, '행정법원');
}

function findCourt(segment) {
  const n = normCourt(segment);
  let best = null;
  for (const c of COURTS) if (n.includes(c) && (!best || c.length > best.length)) best = c;
  return best;
}

function parseCases(text) {
  const re = /(\d{4})\s*([가-힣]{1,5}?)\s*(\d{1,7})(?:\s*-\s*(\d{1,3}))?(?!\d)/g;
  const out = [];
  let last = 0, m;
  while ((m = re.exec(text))) {
    const [raw, year, type, serial, branch] = m;
    if (/^헌/.test(type)) { out.push({ raw, error: '헌법재판소 사건은 이 서비스로 확인할 수 없다' }); last = re.lastIndex; continue; }
    const before = text.slice(last, m.index);
    let court = findCourt(before);
    let courtGuessed = false;
    if (!court && SUPREME_TYPES.has(type)) { court = '대법원'; courtGuessed = true; }
    const item = { raw: raw.trim(), court, courtGuessed, year, type, serial, branch: branch || '' };
    if (!court) item.error = '법원을 특정하지 못했다. 법원명을 함께 적어야 한다';
    out.push(item);
    last = re.lastIndex;
  }
  return out;
}

const WARNING = '주의: 이 결과는 사건번호의 존재 여부만 보여 준다. 사건번호가 존재해도 인용(법원·선고일·부호·판결/결정 구분)이 다르거나, 판결 취지를 잘못 옮기거나, 판결에 없는 문장을 지어낸 환각일 수 있다. 1차 선별용으로만 쓰고, 판결 전문을 직접 열어 대조한 뒤 인용한다.';

const label = (c) => `${c.court || '(법원 미상)'} ${c.year}${c.type}${c.serial}${c.branch ? '-' + c.branch : ''}`;

// ---------- 서버 ----------

async function runServer(opts) {
  const { chromium } = require('playwright-core');
  const outDir = opts.out;
  fs.mkdirSync(outDir, { recursive: true });
  const browser = await chromium.launch({ headless: !opts.headed, channel: 'chrome' });
  const page = await browser.newPage({ viewport: { width: 1400, height: 1000 }, locale: 'ko-KR' });

  const state = { queue: [], current: null, dialogs: [], results: [] };
  page.on('dialog', async (d) => { state.dialogs.push(d.message()); await d.accept().catch(() => {}); });

  let idleTimer;
  const touch = () => { clearTimeout(idleTimer); idleTimer = setTimeout(() => shutdown('idle'), IDLE_MS); };
  async function shutdown(why) { try { await browser.close(); } catch {} process.exit(0); }

  async function openPage() {
    await page.goto(URL_PAGE, { waitUntil: 'networkidle', timeout: 60000 });
    await page.waitForSelector(SEL.captchaImg, { timeout: 30000 });
  }

  async function mainText() {
    return page.evaluate(() => (document.querySelector('#mf_mainFrame') || document.body).innerText);
  }

  async function saveCaptcha() {
    await page.waitForTimeout(300);
    const file = path.join(outDir, `captcha_${Date.now()}.png`);
    await page.locator(SEL.captchaImg).screenshot({ path: file });
    return file;
  }

  async function fillCurrent() {
    const c = state.current;
    await openPage();
    await page.selectOption(SEL.court, { label: c.court });
    await page.fill(SEL.year, c.year);
    await page.fill(SEL.type, c.type);
    await page.fill(SEL.serial, c.serial);
    await page.fill(SEL.branch, c.branch);
    state.baseline = await mainText();
    return saveCaptcha();
  }

  function classify(text) {
    if (/자동\s*입력|방지\s*문자|보안\s*문자/.test(text) && /(일치|틀|잘못|다시)/.test(text)) return 'CAPTCHA_WRONG';
    if (/사건번호가\s*존재하지\s*않습니다/.test(text)) return 'NOT_FOUND';
    if (/사건번호가\s*존재합니다/.test(text)) return 'EXISTS';
    return 'UNKNOWN';
  }

  async function collectResult(c) {
    await page.waitForLoadState('networkidle').catch(() => {});
    await page.waitForTimeout(1200);
    const after = await mainText();
    const base = new Set((state.baseline || '').split('\n').map((s) => s.trim()));
    const diff = after.split('\n').map((s) => s.trim()).filter((s) => s && !base.has(s));
    const popup = await page.evaluate(() =>
      [...document.querySelectorAll('[class*=w2window],[class*=popup],[class*=alert],[role=dialog]')]
        .filter((e) => e.offsetParent).map((e) => e.innerText.trim()).filter(Boolean).join('\n'));
    const msgs = [...state.dialogs, popup, ...diff].filter(Boolean);
    state.dialogs = [];
    const text = [...new Set(msgs.join('\n').split('\n').map((s) => s.trim()).filter((s) => s && s !== '설명'))].join('\n').slice(0, 2000);
    const shot = path.join(outDir, `result_${c.year}${c.type}${c.serial}_${Date.now()}.png`);
    await page.screenshot({ path: shot, fullPage: true });
    const verdict = classify(text);
    const rec = { checkedAt: new Date().toISOString(), case: label(c), input: c.raw, courtGuessed: c.courtGuessed, verdict, message: text, screenshot: shot, contentVerified: false };
    if (verdict !== 'CAPTCHA_WRONG') fs.appendFileSync(path.join(outDir, 'results.jsonl'), JSON.stringify(rec) + '\n');
    return rec;
  }

  async function next() {
    state.current = state.queue.shift() || null;
    if (!state.current) return { done: true, message: '확인할 사건번호가 더 없다' };
    const captcha = await fillCurrent();
    return { case: label(state.current), courtGuessed: state.current.courtGuessed, remaining: state.queue.length, captcha };
  }

  const handlers = {
    async check(body) {
      const parsed = parseCases(body.text || '');
      const bad = parsed.filter((p) => p.error);
      state.queue.push(...parsed.filter((p) => !p.error));
      const r = state.current ? { case: label(state.current), note: '진행 중인 사건이 있어 대기열에 추가했다', remaining: state.queue.length } : await next();
      return { ...r, skipped: bad };
    },
    async answer(body) {
      const c = state.current;
      if (!c) return { error: '진행 중인 사건이 없다. check 먼저' };
      if (body.browser) {
        if (!opts.headed) return { error: '--browser는 --headed 세션에서만 쓴다' };
        const deadline = Date.now() + 180000;
        const base = state.baseline;
        while (Date.now() < deadline) {
          await page.waitForTimeout(1000);
          if (state.dialogs.length || (await mainText()) !== base) break;
        }
      } else {
        const code = String(body.code || '').replace(/\D/g, '');
        if (!code) return { error: '캡차 숫자가 비었다' };
        await page.fill(SEL.captchaInput, code);
        await page.click(SEL.search);
      }
      const rec = await collectResult(c);
      if (rec.verdict === 'CAPTCHA_WRONG') {
        const captcha = await fillCurrent();
        return { ...rec, retry: true, captcha, note: '자동입력방지 문자가 틀렸다. 새 이미지로 다시 입력한다' };
      }
      state.results.push(rec);
      const n = await next();
      return { result: rec, warning: WARNING, next: n };
    },
    async refresh() {
      if (!state.current) return { error: '진행 중인 사건이 없다' };
      return { case: label(state.current), captcha: await fillCurrent() };
    },
    async status() {
      return { current: state.current && label(state.current), queue: state.queue.map(label), results: state.results, outDir, headed: !!opts.headed };
    },
    async stop() { setTimeout(() => shutdown('stop'), 100); return { stopped: true }; },
  };

  let busy = Promise.resolve();
  http.createServer((req, res) => {
    let raw = '';
    req.on('data', (d) => (raw += d));
    req.on('end', () => {
      touch();
      const name = req.url.replace(/^\//, '');
      const h = handlers[name];
      busy = busy.then(async () => {
        let out;
        try { out = h ? await h(raw ? JSON.parse(raw) : {}) : { error: 'unknown command' }; }
        catch (e) { out = { error: String(e && e.message || e) }; }
        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify(out, null, 2));
      });
    });
  }).listen(PORT, '127.0.0.1', () => { touch(); fs.writeFileSync(path.join(outDir, 'server.ready'), String(process.pid)); });
}

// ---------- 클라이언트 ----------

function call(name, body) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body || {});
    const req = http.request({ host: '127.0.0.1', port: PORT, path: '/' + name, method: 'POST', headers: { 'Content-Type': 'application/json' } }, (res) => {
      let raw = ''; res.on('data', (d) => (raw += d)); res.on('end', () => resolve(raw));
    });
    req.on('error', reject);
    req.end(data);
  });
}

async function main() {
  const [cmd, ...args] = process.argv.slice(2);
  const flag = (f) => args.includes(f);
  const optVal = (f, d) => { const i = args.indexOf(f); return i >= 0 ? args[i + 1] : d; };
  const outDir = path.resolve(optVal('--out', path.join(os.homedir(), '.cache', 'case-number-verify')));

  if (cmd === '__server') return runServer({ headed: flag('--headed'), out: outDir });

  if (cmd === 'parse') { console.log(JSON.stringify(parseCases(args.join(' ')), null, 2)); return; }

  if (cmd === 'start') {
    try { console.log(await call('status')); console.log('이미 세션이 떠 있다'); return; } catch {}
    fs.mkdirSync(outDir, { recursive: true });
    const ready = path.join(outDir, 'server.ready');
    try { fs.unlinkSync(ready); } catch {}
    const log = fs.openSync(path.join(outDir, 'server.log'), 'a');
    const child = spawn(process.execPath, [__filename, '__server', ...(flag('--headed') ? ['--headed'] : []), '--out', outDir], { detached: true, stdio: ['ignore', log, log] });
    child.unref();
    for (let i = 0; i < 60 && !fs.existsSync(ready); i++) await new Promise((r) => setTimeout(r, 500));
    console.log(fs.existsSync(ready) ? `세션 시작 (pid ${child.pid}, 결과 폴더 ${outDir})` : `세션 시작 실패. ${path.join(outDir, 'server.log')} 확인`);
    return;
  }

  const map = { check: () => ({ text: args.join(' ') }), answer: () => (flag('--browser') ? { browser: true } : { code: args[0] }), refresh: () => ({}), status: () => ({}), stop: () => ({}) };
  if (!map[cmd]) { console.log(fs.readFileSync(__filename, 'utf8').split('\n').slice(1, 13).join('\n')); process.exit(1); }
  try {
    console.log(await call(cmd, map[cmd]()));
    if (cmd === 'stop') for (let i = 0; i < 40; i++) { try { await call('status'); await new Promise((r) => setTimeout(r, 250)); } catch { break; } }
  }
  catch { console.log('세션이 없다. 먼저 `node cnv.js start` 를 실행한다'); process.exit(1); }
}

main();
