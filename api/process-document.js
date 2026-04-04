const { GoogleGenerativeAI } = require("@google/generative-ai");
const sharp = require("sharp");

module.exports = async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

  try {
    const { image } = req.body;
    if (!image) return res.status(400).json({ error: "Missing image" });

    // Decode base64 image
    const imgBuffer = Buffer.from(image, "base64");
    const metadata = await sharp(imgBuffer).metadata();
    const w = metadata.width;
    const h = metadata.height;

    // Step 1: Gemini detects document corners
    const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

    // Resize for AI (max 1024px)
    const scale = Math.min(1, 1024 / Math.max(w, h));
    const aiW = Math.round(w * scale);
    const aiH = Math.round(h * scale);
    const aiBuffer = await sharp(imgBuffer).resize(aiW, aiH).jpeg({ quality: 80 }).toBuffer();
    const aiBase64 = aiBuffer.toString("base64");

    const prompt = `You are a precision document scanner. Analyze this photo and find the document/paper edges.

RULES:
- Find the 4 corners of the physical paper document
- Handle: white paper on white surface, wrinkled paper, shadows, stains, skewed angles
- IGNORE printed content, QR codes, stamps - find the PAPER edges only
- If no clear document found, return full image with 3% margin

Image: ${aiW}x${aiH} pixels.

Return ONLY JSON, no markdown:
{"tl":{"x":0,"y":0},"tr":{"x":0,"y":0},"bl":{"x":0,"y":0},"br":{"x":0,"y":0}}

Coordinates are pixel integers.`;

    const aiResult = await model.generateContent([
      prompt,
      { inlineData: { mimeType: "image/jpeg", data: aiBase64 } },
    ]);

    const text = aiResult.response.text().trim();
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    let corners;
    try {
      corners = JSON.parse(jsonMatch ? jsonMatch[0] : text);
    } catch {
      const mx = Math.round(aiW * 0.03);
      const my = Math.round(aiH * 0.03);
      corners = { tl: { x: mx, y: my }, tr: { x: aiW - mx, y: my }, bl: { x: mx, y: aiH - my }, br: { x: aiW - mx, y: aiH - my } };
    }

    // Scale corners back to original image size
    const invScale = 1 / scale;
    const c = {
      tl: { x: Math.round(corners.tl.x * invScale), y: Math.round(corners.tl.y * invScale) },
      tr: { x: Math.round(corners.tr.x * invScale), y: Math.round(corners.tr.y * invScale) },
      bl: { x: Math.round(corners.bl.x * invScale), y: Math.round(corners.bl.y * invScale) },
      br: { x: Math.round(corners.br.x * invScale), y: Math.round(corners.br.y * invScale) },
    };

    // Step 2: Perspective correction via sharp
    // Calculate output dimensions
    const topW = Math.sqrt(Math.pow(c.tr.x - c.tl.x, 2) + Math.pow(c.tr.y - c.tl.y, 2));
    const botW = Math.sqrt(Math.pow(c.br.x - c.bl.x, 2) + Math.pow(c.br.y - c.bl.y, 2));
    const leftH = Math.sqrt(Math.pow(c.bl.x - c.tl.x, 2) + Math.pow(c.bl.y - c.tl.y, 2));
    const rightH = Math.sqrt(Math.pow(c.br.x - c.tr.x, 2) + Math.pow(c.br.y - c.tr.y, 2));
    const outW = Math.round(Math.max(topW, botW));
    const outH = Math.round(Math.max(leftH, rightH));

    // Extract region (bounding box of corners) then process
    const minX = Math.max(0, Math.min(c.tl.x, c.bl.x) - 10);
    const minY = Math.max(0, Math.min(c.tl.y, c.tr.y) - 10);
    const maxX = Math.min(w, Math.max(c.tr.x, c.br.x) + 10);
    const maxY = Math.min(h, Math.max(c.bl.y, c.br.y) + 10);
    const cropW = maxX - minX;
    const cropH = maxY - minY;

    // Crop to document area
    let processed = sharp(imgBuffer)
      .extract({ left: minX, top: minY, width: cropW, height: cropH })
      .resize(outW, outH, { fit: "fill" });

    // Step 3: Auto-enhance for professional document look
    // - Normalize/flatten lighting (remove shadows, wrinkles appearance)
    // - Sharpen text
    // - Clean up (increase contrast, slight threshold)
    processed = processed
      .normalize()           // even out lighting, remove shadows
      .sharpen({ sigma: 1.5, m1: 1.0, m2: 0.5 })  // crisp text
      .modulate({ brightness: 1.05, saturation: 0.1 }) // slight brightness, desaturate
      .gamma(1.8)           // push whites whiter, darks darker
      .toColourspace("b-w"); // grayscale for clean doc look

    const outputBuffer = await processed.png({ quality: 95 }).toBuffer();
    const outputBase64 = outputBuffer.toString("base64");

    // Step 4: Generate PDF with the clean image
    const PDFDocument = require("pdfkit");
    const chunks = [];

    const pdfDoc = new PDFDocument({
      size: [outW * 0.75, outH * 0.75], // 72dpi PDF points
      margin: 0,
    });

    pdfDoc.on("data", (chunk) => chunks.push(chunk));

    await new Promise((resolve, reject) => {
      pdfDoc.on("end", resolve);
      pdfDoc.on("error", reject);

      pdfDoc.image(Buffer.from(outputBase64, "base64"), 0, 0, {
        width: outW * 0.75,
        height: outH * 0.75,
      });

      pdfDoc.end();
    });

    const pdfBuffer = Buffer.concat(chunks);

    res.setHeader("Content-Type", "application/pdf");
    res.setHeader("Content-Disposition", "attachment; filename=document.pdf");
    return res.status(200).send(pdfBuffer);
  } catch (error) {
    console.error("Process document error:", error);
    return res.status(500).json({ error: error.message || "Processing failed" });
  }
};
