const { GoogleGenerativeAI } = require("@google/generative-ai");

module.exports = async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

  try {
    const { image, width, height } = req.body;
    if (!image || !width || !height) return res.status(400).json({ error: "Missing image, width, or height" });

    const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash" });

    const prompt = `You are a precision document edge detector. Find the four corners of the physical paper/document in this image.

CRITICAL RULES:
- Detect the OUTER EDGES of the physical paper/document only
- The document may be WHITE PAPER on a WHITE SURFACE - use subtle shadows, slight color differences, paper texture, and edge lines to find it
- IGNORE all printed content, black rectangles, QR codes, text blocks, logos - these are ON the document, not the document edges
- IGNORE any dark borders or phone UI elements
- Look for the physical paper boundary using: shadow lines, slight color shift between paper and surface, paper texture change, slight paper curl/lift
- If multiple papers are visible, detect the LARGEST one
- If truly no document is detectable, return full image with 5% margin

Image is ${width}x${height} pixels.

Return ONLY valid JSON, no markdown, no backticks:
{"topLeft":{"x":0,"y":0},"topRight":{"x":0,"y":0},"bottomLeft":{"x":0,"y":0},"bottomRight":{"x":0,"y":0},"confidence":0.95}

Coordinates are pixel integers within image bounds. confidence is 0.0-1.0.`;

    const result = await model.generateContent([
      prompt,
      { inlineData: { mimeType: "image/jpeg", data: image } },
    ]);

    const text = result.response.text().trim();
    let jsonStr = text;
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (jsonMatch) jsonStr = jsonMatch[0];

    const corners = JSON.parse(jsonStr);
    const clamp = (val, min, max) => Math.max(min, Math.min(max, Math.round(val)));

    return res.status(200).json({
      topLeft: { x: clamp(corners.topLeft.x, 0, width - 1), y: clamp(corners.topLeft.y, 0, height - 1) },
      topRight: { x: clamp(corners.topRight.x, 0, width - 1), y: clamp(corners.topRight.y, 0, height - 1) },
      bottomLeft: { x: clamp(corners.bottomLeft.x, 0, width - 1), y: clamp(corners.bottomLeft.y, 0, height - 1) },
      bottomRight: { x: clamp(corners.bottomRight.x, 0, width - 1), y: clamp(corners.bottomRight.y, 0, height - 1) },
      confidence: corners.confidence || 0.5,
    });
  } catch (error) {
    console.error("Edge detection error:", error);
    const w = req.body.width || 1000;
    const h = req.body.height || 1400;
    const mx = Math.round(w * 0.05);
    const my = Math.round(h * 0.05);
    return res.status(200).json({
      topLeft: { x: mx, y: my },
      topRight: { x: w - mx, y: my },
      bottomLeft: { x: mx, y: h - my },
      bottomRight: { x: w - mx, y: h - my },
      confidence: 0.0,
    });
  }
};
