const crypto = require("crypto");

const JWT_SECRET = process.env.JWT_SECRET;

exports.handler = async (event) => {
  const headers = event.headers || {};
  const authHeader = headers.authorization || headers.Authorization || "";

  if (!authHeader.startsWith("Bearer ")) {
    return { isAuthorized: false };
  }

  const token = authHeader.slice(7);

  try {
    const payload = verifyJWT(token);
    if (!payload) {
      return { isAuthorized: false };
    }
    return { isAuthorized: true };
  } catch (err) {
    console.error("JWT verification failed:", err.message);
    return { isAuthorized: false };
  }
};

function base64UrlDecode(str) {
  str = str.replace(/-/g, "+").replace(/_/g, "/");
  const pad = str.length % 4;
  if (pad) {
    str += "=".repeat(4 - pad);
  }
  return Buffer.from(str, "base64");
}

function verifyJWT(token) {
  const parts = token.split(".");
  if (parts.length !== 3) {
    throw new Error("Invalid token format");
  }

  const [headerB64, payloadB64, signatureB64] = parts;

  // Verify header
  const header = JSON.parse(base64UrlDecode(headerB64).toString());
  if (header.alg !== "HS256" || header.typ !== "JWT") {
    throw new Error("Unsupported algorithm or type");
  }

  // Verify signature
  const signatureInput = `${headerB64}.${payloadB64}`;
  const expectedSignature = crypto
    .createHmac("sha256", JWT_SECRET)
    .update(signatureInput)
    .digest("base64url");

  if (expectedSignature !== signatureB64) {
    throw new Error("Invalid signature");
  }

  // Verify expiration
  const payload = JSON.parse(base64UrlDecode(payloadB64).toString());
  const now = Math.floor(Date.now() / 1000);
  if (payload.exp && payload.exp < now) {
    throw new Error("Token expired");
  }

  return payload;
}
