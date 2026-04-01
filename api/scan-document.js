import { PDFDocument } from 'pdf-lib';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const geminiKey = process.env.GEMINI_API_KEY;
  if (!geminiKey) return res.status(500).json({ error: 'GEMINI_API_KEY nije podesen' });

  let body = req.body;
  if (typeof body === 'string') { try { body = JSON.parse(body); } catch(e) { body = {}; } }

  const { image, width, height } = body || {};
  if (!image) return res.status(400).json({ error: 'Slika nije prosledjena' });

  const base64Data = image.replace(/^data:image\/[a-z]+;base64,/, '');
  const imgW = width || 1200;
  const imgH = height || 1600;

  try {
    const corners = await detectWithGemini(base64Data, imgW, imgH, geminiKey);
    const pdfDoc = await PDFDocument.create();
    const imageBuffer = Buffer.from(base64Data, 'base64');
    const jpgImage = await pdfDoc.embedJpg(imageBuffer);
    let pageW = jpgImage.width;
    let pageH = jpgImage.height;

    if (corners) {
      const minX = Math.max(0, Math.min(...corners.map(c => c.x)));
      const minY = Math.max(0, Math.min(...corners.map(c => c.y)));
      const maxX = Math.min(imgW, Math.max(...corners.map(c => c.x)));
      const maxY = Math.min(imgH, Math.max(...corners.map(c => c.y)));
      const cropW = maxX - minX;
      const cropH = maxY - minY;

      if (cropW > 100 && cropH > 100) {
        const a4W = 595, a4H = 842;
        const scale = Math.min(a4W / cropW, a4H / cropH) * 0.95;
        const drawW = cropW * scale;
        const drawH = cropH * scale;
        const drawX = (a4W - drawW) / 2;
        const drawY = (a4H - drawH) / 2;
        const scaleImgX = drawW / imgW;
        const scaleImgY = drawH / imgH;
        const page = pdfDoc.addPage([a4W, a4H]);
        page.drawImage(jpgImage, {
          x: drawX - minX * scaleImgX,
          y: drawY - (imgH - maxY) * scaleImgY,
          width: imgW * scaleImgX,
          height: imgH * scaleImgY,
        });
        const pdfBytes = await pdfDoc.save();
        res.setHeader('Content-Type', 'application/pdf');
        return res.send(Buffer.from(pdfBytes));
      }
    }

    const page = pdfDoc.addPage([pageW, pageH]);
    page.drawImage(jpgImage, { x: 0, y: 0, width: pageW, height: pageH });
    const pdfBytes = await pdfDoc.save();
    res.setHeader('Content-Type', 'application/pdf');
    return res.send(Buffer.from(pdfBytes));

  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
}

async function detectWithGemini(base64Data, imgW, imgH, apiKey) {
  const prompt = `Find the main document/paper/receipt in this photo. Return ONLY valid JSON:
{"corners": [[y1,x1],[y2,x2],[y3,x3],[y4,x4]], "found": true}
Coordinates normalized 0-1000. Order: top-left, top-right, bottom-right, bottom-left.
If no document: {"found": false}`;

  const models = ['gemini-2.5-flash-lite', 'gemini-2.5-flash', 'gemini-1.5-flash'];
  for (const model of models) {
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 20000);
      const resp = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{ parts: [
              { text: prompt },
              { inlineData: { mimeType: 'image/jpeg', data: base64Data } }
            ]}],
            generationConfig: { temperature: 0, maxOutputTokens: 256 }
          }),
          signal: controller.signal
        }
      ).finally(() => clearTimeout(timeout));

      if (!resp.ok) continue;
      const data = await resp.json();
      const text = data.candidates?.[0]?.content?.parts?.[0]?.text || '';
      let parsed = null;
      try { parsed = JSON.parse(text); } catch(e) {}
      if (!parsed) { const m = text.match(/\{[\s\S]*\}/); if (m) try { parsed = JSON.parse(m[0]); } catch(e) {} }
      if (parsed && parsed.found && parsed.corners && parsed.corners.length === 4) {
        return parsed.corners.map(([y, x]) => ({
          x: Math.round((x / 1000) * imgW),
          y: Math.round((y / 1000) * imgH)
        }));
      }
      break;
    } catch(e) {}
  }
  return null;
}
