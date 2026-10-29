// 27 號工單產生器(單一來源:prompt 文字只在這支檔案與 27 號文件第五節兩處,以本檔為準)。
// 用法(協調者在有 node 的機器上跑;art-director 這邊沒有執行環境,本檔【未執行過】):
//   node build-jobs.js <template_request.json> <out_dir> [start_serial=1] [model_portrait] [model_piece]
// <template_request.json> = AI_IMG queue/jobs/ 底下任一張既有工單的 request.json。
// 本腳本只覆寫 job_id / prompt / negative_prompt / seed / cfg_scale / model(以及 template 若有
// bookkeeping 欄位時的備註),其餘欄位(width/height/steps/sampler/upscale_mode/loras 等)
// 一律沿用 template -- 因為 art-director 讀不到家用端現行工單格式,不替它猜。
// 腳本自己驗:全 ASCII、<=1600 字元、輸出可被 JSON.parse 讀回,並印出每條 prompt 的實測長度。
'use strict';
const fs = require('fs');
const path = require('path');

const [, , tplPath, outDir, startArg, mP, mS] = process.argv;
if (!tplPath || !outDir) { console.error('usage: node build-jobs.js <template> <out_dir> [start] [model_portrait] [model_piece]'); process.exit(2); }
const MODEL_PORTRAIT = mP || 'ronghua-v4.5';       // 26a 裁決的名稱;實際服務端字串以 /v1/models 為準
const MODEL_PIECE = mS || 'arthemy-comics-v2.0';   // 同上
const CFG_PORTRAIT = 3.5, CFG_PIECE = 4;
const DATE = '20261029';
let serial = parseInt(startArg || '1', 10);

// ---------- 共用區塊 ----------
const PORTRAIT_PREFIX = 'bust shot, head and shoulders portrait, slight three-quarter view, single adult character, solo';
const PORTRAIT_STYLE = [
  'semi-realistic character illustration, clear facial structure',
  'natural East Asian skin tone, light warm complexion, not tanned',
  'soft rendered shading with gentle gradients',
  'dim low-key lighting from a single hard-edged source, large shadow areas',
  'muted desaturated cool palette, weary guarded expression',
  'worn clothing with subtle stains and scuff marks',
  'plain flat neutral gray background, no scenery, no background shadow',
  'strong clear silhouette, head and shoulders fully visible with a little padding around the character'
].join(', ');

const PIECE_PREFIX = 'single adult character, solo, full body standing idle pose, front-facing three-quarter view';
const PIECE_STYLE = [
  'hand-drawn comic illustration, not photographic, not a real person',
  'adult body proportions about five heads tall, not chibi',
  'flat cel shading with three tone steps, hard-edged flat color shapes, no soft gradient',
  'bold dark outline around the outer silhouette only, no internal outlines',
  'simplified bold shapes that stay readable at 32x40 pixels, few small details',
  'natural East Asian skin tone, light warm complexion',
  'muted desaturated colors, weary guarded posture',
  'plain flat neutral gray background, no scenery, no background shadow'
].join(', ');

const NEG_COMMON = 'chibi, cute, cheerful smile, bright vivid colors, pastel colors, pristine spotless clothes, multiple people, extra limbs, extra fingers, deformed hands, bad anatomy, text, watermark, logo, signature, scenery, complex background, gradient background, patterned background, shadow on background, reference sheet, multiple views, revealing clothing, dark tanned skin, orange skin, gripping the blade, tool held by its head, reversed tool, upside down tool, floating tool';
const NEG_PORTRAIT = NEG_COMMON + ', full body, wide shot, photograph, 3d render, doll, plastic skin';
const NEG_PIECE = NEG_COMMON + ', cropped, out of frame, close-up, bust only, photograph, photorealistic, soft shading, gradient shading, detailed linework, cross-hatching, internal outlines, soft shadows';
const NEG_AXE = ', axe held backwards, axe blade facing the wrong way, gripping the axe head, upside down axe, axe floating';

// ---------- 角色 ----------
const AXE_DESC = 'a long straight wooden-handled fire axe, the small steel axe head at one end of the handle with a cutting blade on one side and a pointed pick spike on the opposite side of the head';
const CHARACTERS = [
  { key: 'jia', n: 1, name: 'Lan Tingxuan',
    body: 'young adult Taiwanese woman, athletic build, black hair in a tight ponytail, determined weary expression, navy blue firefighter jacket and trousers with faded reflective stripes, fingerless tactical gloves with worn-white knuckles, sturdy scuffed boots, chest gear harness straps',
    bust: 'young adult Taiwanese woman, athletic build, black hair in a tight ponytail, determined weary expression, navy blue firefighter jacket with faded reflective stripes, chest gear harness straps over the shoulders',
    weapons: [   // 三張 seed 對應三種握法(見文件第四節);其餘角色三張同一握法
      'holding ' + AXE_DESC + ' low at her side in one hand, her hand gripping the very end of the handle, the axe head hanging down toward the floor, hand near the hip',
      'standing with both hands resting on top of the end of the handle of ' + AXE_DESC + ', the axe head planted on the ground in front of her, blade facing forward',
      'both hands empty and relaxed at her sides, ' + AXE_DESC + ' slung across her back on a strap, the axe head visible above her shoulder'
    ], axe: true },
  { key: 'yi', n: 2, name: 'Xu Peien',
    body: 'young adult Taiwanese man, lean steady build, short neat black hair, calm composed expression, beige-gray paramedic uniform, dirty-edged first aid pack on the hip, reflective collar patch, dark work gloves, dark work boots',
    bust: 'young adult Taiwanese man, lean steady build, short neat black hair, calm composed expression, beige-gray paramedic uniform with a reflective collar patch, strap of a dirty-edged first aid pack across the chest',
    weapons: ['holding a long-handled steel bolt cutter low at his side in one hand, hand gripping the end of the handles, the cutting jaws pointing down toward the floor'] },
  { key: 'bing', n: 3, name: 'Dong Zhenhao',
    body: 'adult Taiwanese man in his thirties, thin wiry build, weathered face with stubble, wary guarded gaze, worn dark brown work jacket with mud stains, patched olive-brown trousers, coil of rope over one shoulder, scuffed hiking boots, cloth-wrapped hands',
    bust: 'adult Taiwanese man in his thirties, thin wiry build, weathered face with stubble, wary guarded gaze, worn dark brown work jacket with mud stains, coil of rope over one shoulder',
    weapons: ['holding an old long-barreled hunting rifle diagonally across his chest with both hands, one hand on the stock near the hip and one on the forestock, the muzzle pointing up and to the side'] },
  { key: 'ding', n: 4, name: 'Qin Yirou',
    body: 'young adult Taiwanese woman, slim build, black hair in a low neat bun, serious watchful expression, dark navy-black police uniform, duty belt, shoulder radio, scuffed black boots',
    bust: 'young adult Taiwanese woman, slim build, black hair in a low neat bun, serious watchful expression, dark navy-black police uniform, shoulder radio on the collar',
    weapons: ['holding a service pistol low in both hands pointed at the ground, finger resting straight along the frame, the pistol not pointed at the viewer'] },
  { key: 'wu', n: 5, name: 'Mai Zijian',
    body: 'adult Taiwanese man in his thirties, wiry build, slicked-back black hair, calm calculating half-lidded gaze, warm brown-red open-collar jacket over a dark shirt, loose dark trousers, worn leather shoes',
    bust: 'adult Taiwanese man in his thirties, wiry build, slicked-back black hair, calm calculating half-lidded gaze, warm brown-red open-collar jacket over a dark shirt',
    weapons: ['holding a machete low in one hand at his side, hand gripping the handle at the top, the blade pointing down along his leg'] }
];

// ---------- 組裝 ----------
const rows = [];
const tpl = JSON.parse(fs.readFileSync(tplPath, 'utf8'));
for (const c of CHARACTERS) {
  for (const kind of ['portrait', 'piece']) {
    for (let i = 0; i < 3; i++) {
      const weapon = c.weapons[c.weapons.length === 3 ? i : 0];
      const isP = kind === 'portrait';
      // 立繪是胸像:用 c.bust、不帶手持物;握法測試只在棋子做
      const prompt = (isP ? [PORTRAIT_PREFIX, c.bust, PORTRAIT_STYLE] : [PIECE_PREFIX, c.body, weapon, PIECE_STYLE]).join(', ');
      const neg = (isP ? NEG_PORTRAIT : NEG_PIECE) + (c.axe && !isP ? NEG_AXE : '');
      const seed = (isP ? 7000 : 8000) + c.n * 100 + (i + 1);
      const slug = `${c.key}-${kind}-s${seed}`;
      const jobId = `${DATE}-${String(serial).padStart(3, '0')}-${slug}`;
      serial++;
      for (const [label, s] of [['prompt', prompt], ['negative', neg]]) {
        if (!/^[\x20-\x7e]+$/.test(s)) throw new Error(jobId + ' ' + label + ' not ASCII');
        if (s.length > 1600) throw new Error(jobId + ' ' + label + ' > 1600: ' + s.length);
      }
      const req = JSON.parse(JSON.stringify(tpl));
      // 協調者 2026-10-29 修正:工單格式(queue/README.md、20261016-003 範本)把生成參數放在
      // req.generation 底下,不是最外層。尺寸/步數/sampler 取自家用端 10/28~29 實際跑過的
      // comparison_jobs.json(ronghua 立繪)與 arthemy_jobs.json(棋子)。
      const g = req.generation;
      g.prompt = prompt; g.negative_prompt = neg; g.seed = seed;
      g.cfg_scale = isP ? CFG_PORTRAIT : CFG_PIECE; g.model = isP ? MODEL_PORTRAIT : MODEL_PIECE;
      g.width = isP ? 1024 : 896; g.height = isP ? 1024 : 1152;
      g.steps = 30; g.sampler = 'dpmpp_2m'; g.batch_size = 1; g.loras = []; g.upscale_mode = 'native_only';
      req.job_id = jobId; req.created_at = '2026-10-29T10:00:00+08:00'; req.created_by = 'claude-code';
      const note = `27-first-candidate-batch ${c.key} ${kind} variant ${i + 1}/3`;
      req.bookkeeping = { asset_category: isP ? 'portrait' : 'sprite', character_id: c.key, note: note,
        output_filename: `candidate_${c.key}_${kind}_s${seed}.png` };
      const dir = path.join(outDir, jobId);
      fs.mkdirSync(dir, { recursive: true });
      const text = JSON.stringify(req, null, 2) + '\n';
      JSON.parse(text);
      fs.writeFileSync(path.join(dir, 'request.json'), text);
      rows.push([jobId, seed, g.cfg_scale, prompt.length, neg.length]);
    }
  }
}
console.log('job_id | seed | cfg | prompt_chars | negative_chars');
for (const r of rows) console.log(r.join(' | '));
console.log('total jobs: ' + rows.length);
