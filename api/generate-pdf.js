import PDFDocument from 'pdfkit';
import fs from 'fs';
import path from 'path';
function findFont() {
  const candidates = [
    path.join(process.cwd(), 'api', 'fonts', 'DejaVuSansMono.ttf'),
    '/var/task/api/fonts/DejaVuSansMono.ttf',
    '/vercel/path0/api/fonts/DejaVuSansMono.ttf',
  ];
  for (const p of candidates) {
    try { if (fs.existsSync(p) && fs.statSync(p).size > 10000) return p; } catch {}
  }
  return null;
}
async function makeQrPng(text) {
  try {
    const QRCode = await import('qrcode');
    return await QRCode.default.toBuffer(text, { type: 'png', width: 600, margin: 1, errorCorrectionLevel: 'M' });
  } catch (e) { return null; }
}
export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') return res.status(200).end();
  let body = req.body;
  if (typeof body === 'string') try { body = JSON.parse(body); } catch { body = {}; }
  const { journal, qrUrl } = body || {};
  if (!journal) return res.status(400).json({ error: 'Journal tekst je obavezan' });
  try {
    const fontPath = findFont();
    const hasFont = !!fontPath;
    const ptPerMm = 72 / 25.4;
    const W = Math.round(78 * ptPerMm);
    const ML = 6; const MR = 3; const MT = 8;
    const TW = W - ML - MR; const FS = 8.4; const LG = 0.5;
    const allLines = journal.replace(/\r\n/g, '\n').split('\n').map(l => l.trimEnd());
    let footerIdx = -1;
    for (let i = allLines.length - 1; i >= 0; i--) {
      if (/\u041A\u0420\u0410\u0408|KRAJ/i.test(allLines[i])) { footerIdx = i; break; }
    }
    const mainBody = footerIdx >= 0 ? allLines.slice(0, footerIdx) : allLines;
    const krajLine = footerIdx >= 0 ? allLines[footerIdx] : '';
    const measure = new PDFDocument({ size: [W, 10000], margins: { top: MT, bottom: MT, left: ML, right: MR } });
    if (hasFont) { measure.registerFont('Mono', fontPath); measure.font('Mono'); }
    else { measure.font('Courier'); }
    measure.fontSize(FS);
    let currentY = MT;
    mainBody.forEach(line => { currentY += measure.heightOfString(line || ' ', { width: TW, lineGap: LG }); });
    const qrSize = Math.round(50 * ptPerMm);
    if (qrUrl) currentY += qrSize + 25;
    if (krajLine) currentY += measure.heightOfString(krajLine, { width: TW, lineGap: LG }) + 10;
    const finalHeight = currentY + MT;
    measure.end();
    const doc = new PDFDocument({ size: [W, finalHeight], margins: { top: MT, bottom: MT, left: ML, right: MR } });
    if (hasFont) { doc.registerFont('Mono', fontPath); doc.font('Mono'); }
    else { doc.font('Courier'); }
    doc.fontSize(FS);
    mainBody.forEach(line => { doc.text(line, ML, doc.y, { width: TW, align: 'left', lineGap: LG }); });
    if (qrUrl) {
      const qrBuf = await makeQrPng(qrUrl);
      if (qrBuf) {
        doc.moveDown(1);
        const qrX = (W - qrSize) / 2;
        doc.image(qrBuf, qrX, doc.y, { width: qrSize });
        doc.y += qrSize + 15;
      }
    }
    if (krajLine) { doc.text(krajLine, ML, doc.y, { width: TW, align: 'center', lineGap: LG }); }
    const chunks = [];
    doc.on('data', c => chunks.push(c));
    await new Promise((ok, fail) => { doc.on('end', ok); doc.on('error', fail); doc.end(); });
    res.setHeader('Content-Type', 'application/pdf');
    return res.status(200).send(Buffer.concat(chunks));
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
}
