// 29 號工單產生器(單一來源:prompt 文字以本檔為準)。
// 依據 docs/ai-art-service-handoff/28-art-director-review-2026-11-02.md 第 4 節 A
// (管理者 2026-11-02 裁決:立繪「再跑一批插畫版再定(推薦)」、授權「接受,只用在立繪(推薦)」)。
// 沿用 28 號第五節試稿 20261030-101~105 的設定(cheyenne-v2.0 / CFG 4 / 30 steps / dpmpp_2m / 1024²),
// 構圖依審定 D4 改為「胸像、頭完整、含肩、上方留空」。協調者撰寫並執行。
// 用法:node build-jobs.js <template_request.json> <out_dir>
'use strict';
const fs = require('fs');
const path = require('path');

const [, , tplPath, outDir] = process.argv;
if (!tplPath || !outDir) { console.error('usage: node build-jobs.js <template> <out_dir>'); process.exit(2); }
const MODEL = 'cheyenne-v2.0', CFG = 4;
const DATE = '20261102';
let serial = 1;

// D4:不再要求腰部以上
const PREFIX = 'bust portrait showing head and both shoulders, slight three-quarter view, single adult character, solo, the whole head including the top of the hair fully inside the frame with empty space above the head';
const STYLE = [
  'semi-realistic painted character illustration, visible painterly brushwork, illustrated not photographic',
  'clear facial structure, natural East Asian skin tone, light warm complexion, not tanned',
  'soft rendered shading with gentle gradients',
  'dim low-key lighting from a single hard-edged source, large shadow areas',
  'muted desaturated cool palette, weary guarded expression',
  'worn clothing with subtle dust and scuff marks',
  'plain flat neutral gray background, no scenery, no background shadow',
  'strong clear silhouette, generous padding around the character on all sides'
].join(', ');

// 28 號立繪負向原文 + 審定第 4 節 A 通用項(rope cord / gold braid 等)
const NEG = 'chibi, cute, cheerful smile, bright vivid colors, pastel colors, pristine spotless clothes, multiple people, extra limbs, extra fingers, deformed hands, bad anatomy, text, watermark, logo, signature, scenery, complex background, gradient background, patterned background, shadow on background, reference sheet, multiple views, revealing clothing, dark tanned skin, orange skin, blood, wounds, cuts, scars, injuries, bruises, flag, american flag, stars and stripes, fire, flames, smoke, letters, numbers, emblem lettering, writing, name tag, full body, wide shot, cropped head, top of head cut off, extreme close-up, face close-up, photograph, photorealistic, 3d render, doll, plastic skin, t-shirt, topknot, hair bun on top of head, white collar, gold braid, aiguillette, rope cord on shoulder';

const C = {
  // 甲:101 方向;101 出現 prompt 沒寫的黃底紅色臂章 → 負向排除臂章
  jia: { n: 1,
    bust: 'young adult Taiwanese woman, athletic build, black hair in a tight ponytail, determined weary expression, navy blue firefighter jacket with bright silver-white reflective stripes, chest gear harness straps',
    neg: ', armband, arm patch, yellow patch' },
  // 乙:102 方向 + 審定「瀏海、年輕」
  yi: { n: 2,
    bust: 'young adult Taiwanese man in his twenties, youthful face, short neat black hair with bangs, calm composed expression, beige-gray paramedic uniform with a red cross armband on the upper arm',
    neg: ', old man, wrinkles, middle-aged' },
  // 丙:103 方向;棕色工作外套;去重鬍。繩索屬角色本身,故不加 rope 負向(通用負向只排除肩上飾繩)
  bing: { n: 3,
    bust: 'adult Taiwanese man in his thirties, thin wiry build, weathered tired face with light stubble, wary guarded gaze, worn brown work jacket with mud stains, coil of climbing rope over one shoulder, mountain forest survivor look',
    neg: ', heavy beard, full beard, ancient clothing, hanfu, cross collar robe' },
  // 丁:審定「不要文字、金色飾繩、白交領」
  ding: { n: 4,
    bust: 'young adult Taiwanese woman, slim build, black hair in a low neat bun at the nape under the cap, serious watchful expression, dark navy police peaked cap with a silver police badge, dark navy stand-collar police uniform jacket with a plain silver badge on the chest and shoulder patches',
    neg: ', tactical vest, short hair' },
  // 戊:棕外套 + 可見紅內裡、後梳、年輕感(105 太老)
  wu: { n: 5,
    bust: 'adult Taiwanese man in his early thirties, youthful face, wiry build, short slicked-back black hair, calm calculating half-lidded gaze, brown open-collar jacket with a clearly visible red inner lining over a dark shirt',
    neg: ', old man, wrinkles, gray hair, gray jacket, red shirt' }
};

const JOBS = [];
for (const k of ['jia', 'yi', 'bing', 'ding', 'wu'])
  for (let i = 0; i < 3; i++) JOBS.push({ k, seed: 9000 + C[k].n * 100 + 11 + i });

const rows = [];
const tpl = JSON.parse(fs.readFileSync(tplPath, 'utf8'));
for (const j of JOBS) {
  const c = C[j.k];
  const prompt = [PREFIX, c.bust, STYLE].join(', ');
  const neg = NEG + c.neg;
  const jobId = `${DATE}-${String(serial).padStart(3, '0')}-${j.k}-portrait-painted-s${j.seed}`;
  serial++;
  for (const [label, s] of [['prompt', prompt], ['negative', neg]]) {
    if (!/^[\x20-\x7e]+$/.test(s)) throw new Error(jobId + ' ' + label + ' not ASCII');
    if (s.length > 1600) throw new Error(jobId + ' ' + label + ' > 1600: ' + s.length);
  }
  const req = JSON.parse(JSON.stringify(tpl));
  const g = req.generation;
  g.prompt = prompt; g.negative_prompt = neg; g.seed = j.seed;
  g.cfg_scale = CFG; g.model = MODEL; g.width = 1024; g.height = 1024;
  g.steps = 30; g.sampler = 'dpmpp_2m'; g.batch_size = 1; g.loras = []; g.upscale_mode = 'native_only';
  req.job_id = jobId; req.created_at = '2026-11-02T16:00:00+08:00'; req.created_by = 'claude-code';
  req.bookkeeping = { asset_category: 'portrait', character_id: j.k,
    note: `29-painted-portrait-batch ${j.k}`, output_filename: `candidate29_${j.k}_portrait_painted_s${j.seed}.png` };
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
