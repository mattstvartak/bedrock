const enc = new TextEncoder();
const b64url = (b: ArrayBuffer | Uint8Array) =>
	btoa(String.fromCharCode(...new Uint8Array(b))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
export const fromB64url = (s: string) => Uint8Array.from(atob(s.replace(/-/g, "+").replace(/_/g, "/")), (c) => c.charCodeAt(0));

const hmacKey = (secret: string, usage: "sign" | "verify") =>
	crypto.subtle.importKey("raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, [usage]);

// Sessions are 30 days; the client re-auths silently via platform SSO.
export async function mintSession(secret: string, accountId: string): Promise<string> {
	const now = Math.floor(Date.now() / 1000);
	const head = b64url(enc.encode(JSON.stringify({ alg: "HS256", typ: "JWT" })));
	const body = b64url(enc.encode(JSON.stringify({ sub: accountId, iat: now, exp: now + 30 * 86400 })));
	const sig = await crypto.subtle.sign("HMAC", await hmacKey(secret, "sign"), enc.encode(`${head}.${body}`));
	return `${head}.${body}.${b64url(sig)}`;
}

export async function verifySession(secret: string, token: string): Promise<string | null> {
	try {
		const [head, body, sig] = token.split(".");
		if (JSON.parse(new TextDecoder().decode(fromB64url(head))).alg !== "HS256") return null;
		const ok = await crypto.subtle.verify("HMAC", await hmacKey(secret, "verify"), fromB64url(sig), enc.encode(`${head}.${body}`));
		if (!ok) return null;
		const claims = JSON.parse(new TextDecoder().decode(fromB64url(body))) as { sub?: string; exp?: number };
		if (!claims.sub || !claims.exp || claims.exp < Date.now() / 1000) return null;
		return claims.sub;
	} catch {
		return null;
	}
}
