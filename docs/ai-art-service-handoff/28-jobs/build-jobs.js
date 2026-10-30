// 28 號工單產生器(單一來源:prompt 文字以本檔為準;28 號文件只說明規則)。
// 由 27 號 build-jobs.js 複製修改,依據 docs/ai-art-service-handoff/27-art-director-review-2026-10-30.md 第六節
// (管理者 2026-10-30:「我完全同意他的看法」)。協調者撰寫並執行。
// 用法:node build-jobs.js <template_request.json> <out_dir>
'use strict';
const fs = require('fs');
const path = require('path');

const [, , tplPath, outDir] = process.argv;
if (!tplPath || !outDir) { console.error('usage: node build-jobs.js <template> <out_dir>'); process.exit(2); }
const MODEL_PORTRAIT = 'ronghua-v4.5', MODEL_PIECE = 'arthemy-comics-v2.0';
const CFG_PORTRAIT = 3.5, CFG_PIECE = 4;
const DATE = '20261030';
let serial = 1;

// ---------- 共用區塊 ----------
// 立繪:第六節 1 —— 頭頂與肩膀完整、四周留空、半身,避免臉部特寫
const PORTRAIT_PREFIX = 'half body portrait from the waist up, slight three-quarter view, single adult character, solo, the whole head including the top of the hair fully inside the frame with empty space above the head';
const PORTRAIT_STYLE = [
  'semi-realistic character illustration, clear facial structure',
  'natural East Asian skin tone, light warm complexion, not tanned',
  'soft rendered shading with gentle gradients',
  'dim low-key lighting from a single hard-edged source, large shadow areas',
  'muted desaturated cool palette, weary guarded expression',
  'worn clothing with subtle dust and scuff marks',
  'plain flat neutral gray background, no scenery, no background shadow',
  'strong clear silhouette, generous padding around the character on all sides'
].join(', ');

// 棋子:管理者選四頭身(第六節 7);全身含鞋(第六節 4)
const PIECE_PREFIX = 'single adult character, solo, full body from head to feet including shoes, feet fully visible, standing idle pose, front-facing three-quarter view';
const PIECE_STYLE = [
  'hand-drawn comic illustration, not photographic, not a real person',
  'short stocky stylized proportions about four heads tall, slightly large head for readability, adult face, not chibi, not cute',
  'flat cel shading with three tone steps, hard-edged flat color shapes, no soft gradient',
  'bold dark outline around the outer silhouette only, no internal outlines',
  'simplified bold shapes that stay readable at 32x40 pixels, few small details',
  'natural East Asian skin tone, light warm complexion',
  'muted desaturated colors, weary guarded posture',
  'plain flat neutral gray background, no scenery, no background shadow'
].join(', ');

// 第六節 2、6、8:全員排除血跡/傷痕;國旗/火;假字
const NEG_EXTRA = 'blood, wounds, cuts, scars, injuries, bruises, flag, american flag, stars and stripes, fire, flames, smoke, letters, numbers, emblem lettering';
const NEG_COMMON = 'chibi, cute, cheerful smile, bright vivid colors, pastel colors, pristine spotless clothes, multiple people, extra limbs, extra fingers, deformed hands, bad anatomy, text, watermark, logo, signature, scenery, complex background, gradient background, patterned background, shadow on background, reference sheet, multiple views, revealing clothing, dark tanned skin, orange skin, gripping the blade, tool held by its head, reversed tool, upside down tool, floating tool, ' + NEG_EXTRA;
const NEG_PORTRAIT = NEG_COMMON + ', full body, wide shot, cropped head, top of head cut off, extreme close-up, face close-up, photograph, 3d render, doll, plastic skin, t-shirt, topknot, hair bun on top of head, white collar';
const NEG_PIECE = NEG_COMMON + ', cropped, out of frame, feet cut off, close-up, bust only, photograph, photorealistic, soft shading, gradient shading, detailed linework, cross-hatching, internal outlines, soft shadows';
const NEG_AXE = ', axe held backwards, axe blade facing the wrong way, gripping the axe head, upside down axe, axe floating';
const NEG_BLADE = ', katana, sword, samurai sword, curved blade, crossguard, long blade';

// ---------- 角色 ----------
const AXE_DESC = 'a long straight wooden-handled fire axe, the small steel axe head at one end of the handle with a cutting blade on one side and a pointed pick spike on the opposite side of the head';
// 第六節 7:甲丁拉開色彩 —— 甲保留銀白反光條;丁加警帽與警徽(輪廓上一眼可分)
const C = {
  jia: { n: 1,
    body: 'young adult Taiwanese woman, athletic build, black hair in a tight ponytail, determined weary expression, navy blue firefighter jacket and trousers with bright silver-white reflective stripes on arms and legs, fingerless tactical gloves, sturdy scuffed boots, chest gear harness straps',
    // 第六節 6:握法 A(27 號 s8101 唯一照做者)多跑 seed
    weapon: 'holding ' + AXE_DESC + ' low at her side in one hand, her hand gripping the very end of the handle, the axe head hanging down toward the floor, hand near the hip' },
  yi: { n: 2,
    body: 'young adult Taiwanese man, lean steady build, short neat black hair, calm composed expression, beige-gray paramedic uniform with a red cross armband on the upper arm, dusty first aid pack on the hip, dark work gloves, dark work boots',
    // 第六節 3:破壞剪改寫成可畫的外形
    weapon: 'carrying a large bolt cutter in one hand at his side: a big pliers-shaped steel tool with two long straight metal handles with black rubber grips, the two handles held together in one fist, joined at a pivot to short thick heavy steel jaws, the jaws pointing down toward the floor' },
  bing: { n: 3,
    body: 'adult Taiwanese man in his thirties, thin wiry build, weathered face with stubble, wary guarded gaze, worn dark brown work jacket with mud stains, patched olive-brown trousers, coil of rope over one shoulder, scuffed hiking boots, cloth-wrapped hands',
    bust: 'adult Taiwanese man in his thirties, thin wiry build, weathered tired face with stubble, wary guarded gaze, worn dark brown work jacket with mud stains, coil of rope over one shoulder, mountain forest survivor look',
    // 第六節 4
    weapon: 'holding an old long-barreled hunting rifle diagonally across his chest with both hands, one hand on the stock near the hip and one hand on the forestock, the muzzle pointing up and to the side' },
  ding: { n: 4,
    body: 'young adult Taiwanese woman, slim build, black hair in a low neat bun at the nape, serious watchful expression, dark navy police peaked cap with a silver police badge, dark navy-black police uniform with a silver badge on the chest and shoulder patches, duty belt, shoulder radio, scuffed black boots',
    bust: 'young adult Taiwanese woman, slim build, black hair in a low neat bun at the nape, serious watchful expression, dark navy police peaked cap with a silver police badge, dark navy-black police uniform jacket with a silver badge on the chest and shoulder patches, shoulder radio',
    weapon: 'holding a compact black service pistol of normal short size low in both hands pointed at the ground, finger resting straight along the frame, the pistol not pointed at the viewer' },
  wu: { n: 5,
    body: 'adult Taiwanese man in his thirties, wiry build, slicked-back black hair, calm calculating half-lidded gaze, brown open-collar jacket with a red inner lining over a dark shirt, loose dark trousers, worn leather shoes',
    bust: 'adult Taiwanese man in his thirties, wiry build, short slicked-back black hair, calm calculating half-lidded gaze, brown open-collar jacket with a red inner lining over a dark shirt',
    // 第六節 5
    weapon: 'holding a machete low in one hand at his side: a short wide single-edged straight blade with a plain wooden handle and no guard, the blade pointing down along his leg' }
};

// ---------- 工單清單 ----------
// 立繪:丙重產 3(第六節 1);丁 2(警察識別);戊 2(棕外套紅內襯)。其餘角色沿用 27 號已選圖。
// 棋子:四頭身整批重產 5 人 × 3。
const JOBS = [];
for (const [k, cnt] of [['bing', 3], ['ding', 2], ['wu', 2]])
  for (let i = 0; i < cnt; i++) JOBS.push({ k, kind: 'portrait', seed: 7000 + C[k].n * 100 + 11 + i });
for (const k of ['jia', 'yi', 'bing', 'ding', 'wu'])
  for (let i = 0; i < 3; i++) JOBS.push({ k, kind: 'piece', seed: 8000 + C[k].n * 100 + 11 + i });

const rows = [];
const tpl = JSON.parse(fs.readFileSync(tplPath, 'utf8'));
for (const j of JOBS) {
  const c = C[j.k], isP = j.kind === 'portrait';
  const prompt = (isP ? [PORTRAIT_PREFIX, c.bust, PORTRAIT_STYLE] : [PIECE_PREFIX, c.body, c.weapon, PIECE_STYLE]).join(', ');
  const neg = (isP ? NEG_PORTRAIT : NEG_PIECE) + (!isP && j.k === 'jia' ? NEG_AXE : '') + (!isP && j.k === 'wu' ? NEG_BLADE : '');
  const jobId = `${DATE}-${String(serial).padStart(3, '0')}-${j.k}-${j.kind}-s${j.seed}`;
  serial++;
  for (const [label, s] of [['prompt', prompt], ['negative', neg]]) {
    if (!/^[\x20-\x7e]+$/.test(s)) throw new Error(jobId + ' ' + label + ' not ASCII');
    if (s.length > 1600) throw new Error(jobId + ' ' + label + ' > 1600: ' + s.length);
  }
  const req = JSON.parse(JSON.stringify(tpl));
  const g = req.generation;
  g.prompt = prompt; g.negative_prompt = neg; g.seed = j.seed;
  g.cfg_scale = isP ? CFG_PORTRAIT : CFG_PIECE; g.model = isP ? MODEL_PORTRAIT : MODEL_PIECE;
  g.width = isP ? 1024 : 896; g.height = isP ? 1024 : 1152;
  g.steps = 30; g.sampler = 'dpmpp_2m'; g.batch_size = 1; g.loras = []; g.upscale_mode = 'native_only';
  req.job_id = jobId; req.created_at = '2026-10-30T17:00:00+08:00'; req.created_by = 'claude-code';
  req.bookkeeping = { asset_category: isP ? 'portrait' : 'sprite', character_id: j.k,
    note: `28-second-candidate-batch ${j.k} ${j.kind}`, output_filename: `candidate28_${j.k}_${j.kind}_s${j.seed}.png` };
  const dir = path.join(outDir, jobId);
  fs.mkdirSync(dir, { recursive: true });
  const text = JSON.stringify(req, null, 2) + '\n';
  JSON.parse(text);
  fs.writeFileSync(path.join(dir, 'request.json'), text);
  rows.push([jobId, j.seed, g.model, prompt.length, neg.length]);
}
console.log('job_id | seed | model | prompt_chars | negative_chars');
for (const r of rows) console.log(r.join(' | '));
console.log('total jobs: ' + rows.length);
