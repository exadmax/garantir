import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { deflateSync } from 'node:zlib';

const OUTPUTS = [
  { path: 'web/favicon.png', size: 64, maskable: false },
  { path: 'web/icons/Icon-192.png', size: 192, maskable: false },
  { path: 'web/icons/Icon-512.png', size: 512, maskable: false },
  { path: 'web/icons/Icon-maskable-192.png', size: 192, maskable: true },
  { path: 'web/icons/Icon-maskable-512.png', size: 512, maskable: true },
  { path: 'android/app/src/main/res/mipmap-mdpi/ic_launcher.png', size: 48, maskable: false },
  { path: 'android/app/src/main/res/mipmap-hdpi/ic_launcher.png', size: 72, maskable: false },
  { path: 'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png', size: 96, maskable: false },
  { path: 'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png', size: 144, maskable: false },
  { path: 'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png', size: 192, maskable: false },
];

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function mix(a, b, t) {
  return a + (b - a) * t;
}

function lerpColor(a, b, t) {
  return [
    Math.round(mix(a[0], b[0], t)),
    Math.round(mix(a[1], b[1], t)),
    Math.round(mix(a[2], b[2], t)),
    Math.round(mix(a[3], b[3], t)),
  ];
}

function crc32(buffer) {
  let crc = 0xffffffff;
  for (const byte of buffer) {
    crc ^= byte;
    for (let i = 0; i < 8; i += 1) {
      const mask = -(crc & 1);
      crc = (crc >>> 1) ^ (0xedb88320 & mask);
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function pngChunk(type, data) {
  const typeBuffer = Buffer.from(type, 'ascii');
  const lengthBuffer = Buffer.alloc(4);
  lengthBuffer.writeUInt32BE(data.length, 0);
  const crcBuffer = Buffer.alloc(4);
  crcBuffer.writeUInt32BE(crc32(Buffer.concat([typeBuffer, data])), 0);
  return Buffer.concat([lengthBuffer, typeBuffer, data, crcBuffer]);
}

function encodePng(width, height, rgbaBuffer) {
  const stride = width * 4;
  const raw = Buffer.alloc((stride + 1) * height);

  for (let y = 0; y < height; y += 1) {
    const rawRow = y * (stride + 1);
    const srcRow = y * stride;
    raw[rawRow] = 0;
    rgbaBuffer.copy(raw, rawRow + 1, srcRow, srcRow + stride);
  }

  const signature = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;
  ihdr[9] = 6;
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;

  const idat = deflateSync(raw, { level: 9 });

  return Buffer.concat([
    signature,
    pngChunk('IHDR', ihdr),
    pngChunk('IDAT', idat),
    pngChunk('IEND', Buffer.alloc(0)),
  ]);
}

function writePixel(buffer, width, x, y, color) {
  const offset = (y * width + x) * 4;
  buffer[offset] = color[0];
  buffer[offset + 1] = color[1];
  buffer[offset + 2] = color[2];
  buffer[offset + 3] = color[3];
}

function drawRoundedBackground(buffer, width, height, radius) {
  const topLeft = [11, 92, 114, 255];
  const bottomRight = [26, 150, 175, 255];
  const highlight = [104, 219, 234, 255];
  const shadow = [7, 54, 75, 255];

  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const nx = x / (width - 1);
      const ny = y / (height - 1);
      const gradientT = clamp((nx * 0.7) + (ny * 0.3), 0, 1);
      const base = lerpColor(topLeft, bottomRight, gradientT);

      const dx = nx - 0.28;
      const dy = ny - 0.22;
      const glow = Math.max(0, 1 - Math.sqrt(dx * dx + dy * dy) / 0.75);
      const glowMix = glow * glow * 0.26;
      const bg = lerpColor(base, highlight, glowMix);

      const edgeDx = Math.min(nx, 1 - nx);
      const edgeDy = Math.min(ny, 1 - ny);
      const edgeDistance = Math.min(edgeDx, edgeDy) * width;
      const cornerDistance = Math.sqrt(
        Math.pow(Math.max(0, radius - Math.min(x + 0.5, width - x - 0.5)), 2) +
        Math.pow(Math.max(0, radius - Math.min(y + 0.5, height - y - 0.5)), 2),
      );

      const nearCorner =
        (x < radius && y < radius && Math.hypot(radius - x - 0.5, radius - y - 0.5) > radius) ||
        (x >= width - radius && y < radius && Math.hypot(x - (width - radius) + 0.5, radius - y - 0.5) > radius) ||
        (x < radius && y >= height - radius && Math.hypot(radius - x - 0.5, y - (height - radius) + 0.5) > radius) ||
        (x >= width - radius && y >= height - radius && Math.hypot(x - (width - radius) + 0.5, y - (height - radius) + 0.5) > radius);

      if (nearCorner && edgeDistance > radius) {
        writePixel(buffer, width, x, y, [0, 0, 0, 0]);
      } else {
        const vignette = clamp(1 - Math.hypot(nx - 0.5, ny - 0.55) * 1.35, 0, 1);
        const vignetteColor = lerpColor(bg, shadow, vignette * 0.12);
        writePixel(buffer, width, x, y, vignetteColor);
      }
    }
  }
}

function drawEmblem(buffer, width, height, maskable) {
  const cx = width / 2;
  const cy = height / 2 + height * 0.02;
  const outer = width * (maskable ? 0.27 : 0.29);
  const inner = outer * 0.66;
  const stroke = outer - inner;
  const gapAngleMin = -0.55;
  const gapAngleMax = 0.18;

  const ringColor = [255, 255, 255, 240];
  const barColor = [240, 248, 250, 245];
  const softCenter = [255, 255, 255, 42];

  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const dx = x + 0.5 - cx;
      const dy = y + 0.5 - cy;
      const dist = Math.hypot(dx, dy);
      const angle = Math.atan2(dy, dx);

      if (dist < inner * 0.72) {
        const glow = clamp(1 - dist / (inner * 0.72), 0, 1);
        const mixT = glow * 0.15;
        const current = [
          buffer[(y * width + x) * 4],
          buffer[(y * width + x) * 4 + 1],
          buffer[(y * width + x) * 4 + 2],
          buffer[(y * width + x) * 4 + 3],
        ];
        const blended = lerpColor(current, softCenter, mixT);
        writePixel(buffer, width, x, y, blended);
      }

      const inRing = dist >= inner && dist <= outer;
      const inGap = angle >= gapAngleMin && angle <= gapAngleMax && x > cx;
      if (inRing && !inGap) {
        writePixel(buffer, width, x, y, ringColor);
      }

      const barX1 = cx + inner * 0.12;
      const barX2 = cx + outer * 0.45;
      const barHalf = stroke * 0.32;
      if (x >= barX1 && x <= barX2 && Math.abs(dy) <= barHalf && dist <= outer * 0.78) {
        writePixel(buffer, width, x, y, barColor);
      }
    }
  }

  // Small accent notch to strengthen the "G" silhouette.
  const notchWidth = Math.max(1, Math.round(width * 0.06));
  const notchHeight = Math.max(1, Math.round(height * 0.16));
  const notchX = Math.round(cx + outer * 0.18);
  const notchY = Math.round(cy - notchHeight / 2);
  for (let y = notchY; y < notchY + notchHeight; y += 1) {
    for (let x = notchX; x < notchX + notchWidth; x += 1) {
      const dx = x + 0.5 - cx;
      const dy = y + 0.5 - cy;
      const dist = Math.hypot(dx, dy);
      if (dist <= outer * 0.82) {
        writePixel(buffer, width, x, y, [22, 133, 155, 255]);
      }
    }
  }
}

function renderIcon(size, maskable) {
  const buffer = Buffer.alloc(size * size * 4);
  const radius = Math.round(size * 0.22);

  drawRoundedBackground(buffer, size, size, radius);
  drawEmblem(buffer, size, size, maskable);

  return encodePng(size, size, buffer);
}

for (const output of OUTPUTS) {
  const filePath = join(process.cwd(), output.path);
  mkdirSync(dirname(filePath), { recursive: true });
  const png = renderIcon(output.size, output.maskable);
  writeFileSync(filePath, png);
  console.log(`Wrote ${output.path}`);
}