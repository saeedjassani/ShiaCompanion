'use strict';
// The status bar strip has to sit on the app bar's own colour, and the frame's
// screen background on the capture's bottom row, or both read as pasted on.
// Both come out of the PNG itself rather than a hardcoded palette, which is
// what lets one framing pass serve light and dark captures alike.
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

/** Decodes enough of a PNG to read individual pixels. */
function decode(file) {
  const buf = fs.readFileSync(file);
  let pos = 8;
  let width = 0, height = 0, bitDepth = 0, colourType = 0;
  const idat = [];
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos);
    const type = buf.toString('ascii', pos + 4, pos + 8);
    const data = buf.subarray(pos + 8, pos + 8 + len);
    if (type === 'IHDR') {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      bitDepth = data[8];
      colourType = data[9];
    } else if (type === 'IDAT') {
      idat.push(data);
    } else if (type === 'IEND') break;
    pos += 12 + len;
  }
  if (bitDepth !== 8 || (colourType !== 2 && colourType !== 6)) {
    throw new Error(`${path.basename(file)}: unsupported PNG (depth ${bitDepth}, colour ${colourType})`);
  }
  const channels = colourType === 6 ? 4 : 3;
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const stride = width * channels;
  const out = Buffer.alloc(height * stride);

  // Undo the per-scanline filters. Every row carries its filter type in a
  // leading byte, and most reference the row above, so this cannot be done
  // for one row in isolation - hence unfiltering the whole image.
  for (let y = 0; y < height; y++) {
    const filter = raw[y * (stride + 1)];
    const src = raw.subarray(y * (stride + 1) + 1, y * (stride + 1) + 1 + stride);
    const cur = out.subarray(y * stride, (y + 1) * stride);
    const prev = y ? out.subarray((y - 1) * stride, y * stride) : Buffer.alloc(stride);
    for (let x = 0; x < stride; x++) {
      const a = x >= channels ? cur[x - channels] : 0;
      const b = prev[x];
      const c = x >= channels ? prev[x - channels] : 0;
      let v = src[x];
      switch (filter) {
        case 1: v += a; break;
        case 2: v += b; break;
        case 3: v += (a + b) >> 1; break;
        case 4: {
          const p = a + b - c;
          const pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
          v += (pa <= pb && pa <= pc) ? a : (pb <= pc ? b : c);
          break;
        }
      }
      cur[x] = v & 0xff;
    }
  }
  return {width, height, channels, pixels: out};
}

function hexAt(img, x, y) {
  const i = y * img.width * img.channels + x * img.channels;
  return '#' + [img.pixels[i], img.pixels[i + 1], img.pixels[i + 2]]
    .map((v) => v.toString(16).padStart(2, '0')).join('');
}

/** {top, bottom} per capture in `dir`, keyed by filename without extension. */
function sampleBarColours(dir) {
  const out = {};
  if (!fs.existsSync(dir)) return out;
  for (const f of fs.readdirSync(dir).filter((f) => f.endsWith('.png'))) {
    const img = decode(path.join(dir, f));
    out[f.slice(0, -4)] = {
      top: hexAt(img, 12, 12),
      bottom: hexAt(img, 12, img.height - 6),
    };
  }
  return out;
}

module.exports = {sampleBarColours};
