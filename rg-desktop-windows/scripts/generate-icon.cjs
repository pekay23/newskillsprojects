// Generates a simple RG-branded 1024x1024 PNG icon for Tauri.
// Uses pure Node.js (no external deps) to write a valid PNG.
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const SIZE = 1024;

// RGBA pixel buffer
const buf = Buffer.alloc(SIZE * SIZE * 4);

// Brand colors
const NAVY = [15, 27, 45]; // #0f1b2d
const BLUE = [30, 94, 255]; // #1e5eff
const TEAL = [14, 165, 164]; // #0ea5a4
const WHITE = [255, 255, 255];

function setPixel(x, y, [r, g, b], alpha = 255) {
  const idx = (y * SIZE + x) * 4;
  buf[idx] = r;
  buf[idx + 1] = g;
  buf[idx + 2] = b;
  buf[idx + 3] = alpha;
}

// Rounded-rectangle background with gradient (navy -> blue)
function inRoundedRect(x, y, x0, y0, x1, y1, radius) {
  if (x < x0 || x > x1 || y < y0 || y > y1) return false;
  const cx = Math.max(x0 + radius, Math.min(x, x1 - radius));
  const cy = Math.max(y0 + radius, Math.min(y, y1 - radius));
  const dx = x - cx;
  const dy = y - cy;
  return dx * dx + dy * dy <= radius * radius;
}

const MARGIN = 64;
const RADIUS = 180;

for (let y = 0; y < SIZE; y++) {
  for (let x = 0; x < SIZE; x++) {
    if (inRoundedRect(x, y, MARGIN, MARGIN, SIZE - MARGIN, SIZE - MARGIN, RADIUS)) {
      // Gradient from navy (top-left) to blue (bottom-right)
      const t = (x + y) / (2 * SIZE);
      const r = Math.round(NAVY[0] + (BLUE[0] - NAVY[0]) * t);
      const g = Math.round(NAVY[1] + (BLUE[1] - NAVY[1]) * t);
      const b = Math.round(NAVY[2] + (BLUE[2] - NAVY[2]) * t);
      setPixel(x, y, [r, g, b]);
    } else {
      setPixel(x, y, [0, 0, 0], 0);
    }
  }
}

// Draw "RG" text using a simple 5x7 pixel font scaled up.
// Each letter is defined as rows of bits.
const FONT = {
  R: [
    "11110",
    "10001",
    "10001",
    "11110",
    "10100",
    "10010",
    "10001",
  ],
  G: [
    "01111",
    "10000",
    "10000",
    "10111",
    "10001",
    "10001",
    "01110",
  ],
};

const SCALE = 40; // each font pixel = 40x40 screen pixels
const LETTER_W = 5 * SCALE;
const LETTER_H = 7 * SCALE;
const GAP = 2 * SCALE;
const TOTAL_W = LETTER_W * 2 + GAP;
const TOTAL_H = LETTER_H;
const START_X = Math.floor((SIZE - TOTAL_W) / 2);
const START_Y = Math.floor((SIZE - TOTAL_H) / 2);

function drawLetter(letter, offsetX) {
  const rows = FONT[letter];
  for (let fy = 0; fy < rows.length; fy++) {
    for (let fx = 0; fx < rows[fy].length; fx++) {
      if (rows[fy][fx] === "1") {
        const x0 = START_X + offsetX + fx * SCALE;
        const y0 = START_Y + fy * SCALE;
        for (let dy = 0; dy < SCALE; dy++) {
          for (let dx = 0; dx < SCALE; dx++) {
            const px = x0 + dx;
            const py = y0 + dy;
            if (px >= 0 && px < SIZE && py >= 0 && py < SIZE) {
              setPixel(px, py, WHITE);
            }
          }
        }
      }
    }
  }
}

drawLetter("R", 0);
drawLetter("G", LETTER_W + GAP);

// Write PNG manually
function crc32(data) {
  let c;
  const table = [];
  for (let n = 0; n < 256; n++) {
    c = n;
    for (let k = 0; k < 8; k++) {
      c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    }
    table[n] = c >>> 0;
  }
  let crc = 0xffffffff;
  for (let i = 0; i < data.length; i++) {
    crc = table[(crc ^ data[i]) & 0xff] ^ (crc >>> 8);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const typeBuf = Buffer.from(type, "ascii");
  const crcBuf = Buffer.alloc(4);
  crcBuf.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])), 0);
  return Buffer.concat([len, typeBuf, data, crcBuf]);
}

const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(SIZE, 0);
ihdr.writeUInt32BE(SIZE, 4);
ihdr[8] = 8; // bit depth
ihdr[9] = 6; // color type RGBA
ihdr[10] = 0;
ihdr[11] = 0;
ihdr[12] = 0;

// Raw image data with filter byte 0 per row
const raw = Buffer.alloc((SIZE * 4 + 1) * SIZE);
for (let y = 0; y < SIZE; y++) {
  raw[y * (SIZE * 4 + 1)] = 0;
  buf.copy(raw, y * (SIZE * 4 + 1) + 1, y * SIZE * 4, (y + 1) * SIZE * 4);
}

const png = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  chunk("IHDR", ihdr),
  chunk("IDAT", zlib.deflateSync(raw)),
  chunk("IEND", Buffer.alloc(0)),
]);

const outDir = path.join(__dirname, "..", "src-tauri", "icons");
fs.mkdirSync(outDir, { recursive: true });
const outPath = path.join(outDir, "icon-source.png");
fs.writeFileSync(outPath, png);
console.log("Generated icon source:", outPath);