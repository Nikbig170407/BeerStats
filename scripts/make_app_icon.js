// make_app_icon.js – rechnet das App-Icon aus dem Beerpong-Plakat "Der Wurf".
//
// Dieselbe Zeichnung wie `BeerpongPoster.swift`, hier als SVG, wie sie am
// 6. November in der Vorschau abgenommen wurde. Wer das Plakat in Swift
// aendert, aendert es hier mit und rechnet das Icon neu – sonst sieht die
// App anders aus als ihr Symbol.
//
// Aufruf (braucht Node und Playwright mit Chromium, wie in der
// Cloud-Sitzung vorhanden):
//
//   node scripts/make_app_icon.js
//
// Schreibt Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png, als
// PNG ohne Alphakanal – iOS will Icons ohne, und Chromium liefert einen mit.
// Umgewandelt wird hier mit Node-Bordmitteln (zlib), ohne Bildbibliothek.

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const { chromium } = require('playwright');

// --- PNG: RGBA hinein, RGB heraus ---------------------------------------

const CRC = new Uint32Array(256).map((_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});
function crc32(buf) {
  let c = 0xffffffff;
  for (const b of buf) c = CRC[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
function paeth(a, b, c) {
  const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
  return pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
}
function dropAlpha(png) {
  let pos = 8, width = 0, height = 0, colorType = 0;
  const idat = [];
  while (pos < png.length) {
    const len = png.readUInt32BE(pos), type = png.toString('ascii', pos + 4, pos + 8);
    const data = png.subarray(pos + 8, pos + 8 + len);
    if (type === 'IHDR') { width = data.readUInt32BE(0); height = data.readUInt32BE(4); colorType = data[9]; }
    if (type === 'IDAT') idat.push(data);
    pos += 12 + len;
  }
  if (colorType === 2) return png;
  if (colorType !== 6) throw new Error('Unerwartete PNG-Farbart ' + colorType);
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const bpp = 4, stride = width * bpp;
  const out = Buffer.alloc(height * (1 + width * 3));
  let prev = Buffer.alloc(stride);
  for (let y = 0; y < height; y++) {
    const filter = raw[y * (stride + 1)];
    const line = Buffer.from(raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1)));
    for (let x = 0; x < stride; x++) {
      const a = x >= bpp ? line[x - bpp] : 0, b = prev[x], c = x >= bpp ? prev[x - bpp] : 0;
      const add = filter === 1 ? a : filter === 2 ? b : filter === 3 ? (a + b) >> 1 : filter === 4 ? paeth(a, b, c) : 0;
      line[x] = (line[x] + add) & 0xff;
    }
    const o = y * (1 + width * 3);
    out[o] = 0;
    for (let x = 0; x < width; x++) {
      out[o + 1 + x * 3] = line[x * 4];
      out[o + 2 + x * 3] = line[x * 4 + 1];
      out[o + 3 + x * 3] = line[x * 4 + 2];
    }
    prev = line;
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0); ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; ihdr[9] = 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  return Buffer.concat([
    png.subarray(0, 8), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(out, { level: 9 })), chunk('IEND', Buffer.alloc(0))
  ]);
}

// --- Das Plakat ----------------------------------------------------------

const INK = '#2a0c07', CREAM = '#f6ecd9', ORANGE = '#f2a93b', YELLOW = '#ffd27a';
const f1 = (n) => n.toFixed(1);

function star(cx, cy, r, ri, n) {
  const p = [];
  for (let k = 0; k < n * 2; k++) {
    const a = Math.PI * k / n - Math.PI / 2, rr = k % 2 ? ri : r;
    p.push(`${f1(cx + Math.cos(a) * rr)},${f1(cy + Math.sin(a) * rr)}`);
  }
  return p.join(' ');
}
const sparkle = (x, y, r, c = YELLOW) => `<polygon points="${star(x, y, r, r * 0.3, 4)}" fill="${c}"/>`;

function cup(x, y, s) {
  const rw = 18 * s, rh = 6 * s, bw = 13 * s, hh = 34 * s;
  const kontur = f1(2.2 * Math.max(1, s * 0.8));
  const body = `M${f1(x - rw)} ${f1(y)} L${f1(x - bw)} ${f1(y + hh)} Q${f1(x)} ${f1(y + hh + 5 * s)} ${f1(x + bw)} ${f1(y + hh)} L${f1(x + rw)} ${f1(y)} Z`;
  const glanz = `M${f1(x - rw * 0.72)} ${f1(y + 3 * s)} L${f1(x - bw * 0.62)} ${f1(y + hh - 2 * s)} L${f1(x - bw * 0.3)} ${f1(y + hh - s)} L${f1(x - rw * 0.42)} ${f1(y + 3 * s)} Z`;
  return `<path d="${body}" fill="#d8342a" stroke="${INK}" stroke-width="${kontur}" stroke-linejoin="round"/>
    <path d="${glanz}" fill="#f2664a" opacity=".85"/>
    <path d="M${f1(x - rw * 0.93)} ${f1(y + 9 * s)} Q${f1(x)} ${f1(y + 13 * s)} ${f1(x + rw * 0.93)} ${f1(y + 9 * s)}" fill="none" stroke="${INK}" stroke-width="${f1(1.1 * s)}" opacity=".45"/>
    <path d="M${f1(x - rw * 0.8)} ${f1(y + 21 * s)} Q${f1(x)} ${f1(y + 25 * s)} ${f1(x + rw * 0.8)} ${f1(y + 21 * s)}" fill="none" stroke="${INK}" stroke-width="${f1(1.1 * s)}" opacity=".45"/>
    <ellipse cx="${x}" cy="${y}" rx="${f1(rw)}" ry="${f1(rh)}" fill="${CREAM}" stroke="${INK}" stroke-width="${f1(2 * Math.max(1, s * 0.8))}"/>
    <ellipse cx="${x}" cy="${f1(y + 0.6 * s)}" rx="${f1(rw * 0.8)}" ry="${f1(rh * 0.68)}" fill="${ORANGE}"/>
    <ellipse cx="${f1(x - rw * 0.25)}" cy="${f1(y)}" rx="${f1(rw * 0.32)}" ry="${f1(rh * 0.3)}" fill="#fff4d6" opacity=".9"/>`;
}

function poster() {
  const grund = `<radialGradient id="g" gradientUnits="userSpaceOnUse" cx="150" cy="152" r="260"><stop offset="0" stop-color="#3150b8"/><stop offset="1" stop-color="#0c1844"/></radialGradient>
    <pattern id="d" width="10" height="10" patternUnits="userSpaceOnUse"><circle cx="5" cy="5" r="1.5" fill="#fff" opacity=".09"/></pattern>`;
  const tisch = `<path d="M-40 300 L62 128 L238 128 L340 300 Z" fill="#14563f" stroke="${INK}" stroke-width="3" stroke-linejoin="round"/>
    <path d="M-22 300 L70 140 L230 140 L322 300" fill="none" stroke="${CREAM}" stroke-width="2.4" opacity=".85"/>
    <path d="M150 210 L150 300" stroke="${CREAM}" stroke-width="2" stroke-dasharray="9 7" stroke-linecap="round" opacity=".55"/>
    <path d="M62 128 L238 128 L240 137 L60 137 Z" fill="#0b3a29"/>`;
  const hinten = [[114, 136, .9], [150, 136, .9], [186, 136, .9], [132, 158, .98], [168, 158, .98], [150, 182, 1.06]]
    .map(([x, y, s]) => cup(x, y, s)).join('');
  const bahn = `<path d="M-6 210 C16 110 52 62 92 52" fill="none" stroke="${CREAM}" stroke-width="3.2" stroke-dasharray="2 10" stroke-linecap="round" opacity=".85"/>
    <path d="M124 56 C140 66 150 92 150 166" fill="none" stroke="${YELLOW}" stroke-width="2.4" stroke-dasharray="1 8" stroke-linecap="round" opacity=".9"/>
    <path d="M70 40 L88 45 M64 56 L86 56 M70 72 L88 66" stroke="${CREAM}" stroke-width="2.8" stroke-linecap="round" opacity=".75"/>`;
  const ball = `<ellipse cx="118" cy="214" rx="16" ry="5" fill="#000" opacity=".28"/>
    <circle cx="108" cy="54" r="16" fill="#fffaf0" stroke="${INK}" stroke-width="3"/>
    <path d="M98 47 Q103 41 111 42" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round"/>
    <path d="M96 62 Q108 72 121 60" fill="none" stroke="${ORANGE}" stroke-width="2.4" stroke-linecap="round" opacity=".8"/>`;
  const vorn = cup(26, 258, 1.95) + cup(274, 258, 1.95);
  return `<svg viewBox="0 0 300 300" width="1024" height="1024" xmlns="http://www.w3.org/2000/svg"><defs>${grund}</defs>
    <rect width="300" height="300" fill="url(#g)"/><rect width="300" height="300" fill="url(#d)"/>
    ${tisch}${hinten}${bahn}${ball}${vorn}
    ${sparkle(236, 46, 10)}${sparkle(266, 92, 6)}${sparkle(40, 128, 5, CREAM)}${sparkle(210, 214, 6)}</svg>`;
}

(async () => {
  const ziel = path.join(__dirname, '..', 'Resources', 'Assets.xcassets', 'AppIcon.appiconset', 'icon-1024.png');
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1024, height: 1024 }, deviceScaleFactor: 1 });
  await page.setContent(`<!doctype html><html><body style="margin:0;background:#0c1844">${poster()}</body></html>`);
  const bild = await page.screenshot({ clip: { x: 0, y: 0, width: 1024, height: 1024 } });
  await browser.close();
  fs.writeFileSync(ziel, dropAlpha(bild));
  console.log('geschrieben:', ziel);
})();
