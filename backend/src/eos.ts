const JWKS_URL = "https://api.epicgames.dev/auth/v1/oauth/jwks";
const ISSUER = "https://api.epicgames.dev/auth/v1/oauth";

type Jwk = JsonWebKey & { kid?: string };
let cached: { keys: Jwk[]; at: number } | null = null;

async function epicKeys(env: Env, refresh: boolean): Promise<Jwk[]> {
	if (env.EOS_JWKS) return (JSON.parse(env.EOS_JWKS) as { keys: Jwk[] }).keys; // tests only
	if (!refresh && cached && Date.now() - cached.at < 3_600_000) return cached.keys;
	const res = await fetch(JWKS_URL);
	if (!res.ok) return cached?.keys ?? [];
	cached = { keys: ((await res.json()) as { keys: Jwk[] }).keys, at: Date.now() };
	return cached.keys;
}

const bytes = (s: string) => Uint8Array.from(atob(s.replace(/-/g, "+").replace(/_/g, "/")), (c) => c.charCodeAt(0));
const decode = (s: string) => JSON.parse(new TextDecoder().decode(bytes(s)));

// An EOS Connect ID token signed by Epic for our client and product. Returns its PUID, or null.
export async function verifyEosIdToken(env: Env, token: string): Promise<string | null> {
	try {
		const [h, p, sig] = token.split(".");
		const head = decode(h);
		if (head.alg !== "RS256" || !sig) return null;
		const jwk = (await epicKeys(env, false)).find((k) => k.kid === head.kid) ?? (await epicKeys(env, true)).find((k) => k.kid === head.kid);
		if (!jwk) return null;
		const key = await crypto.subtle.importKey("jwk", { kty: jwk.kty, n: jwk.n, e: jwk.e }, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
		if (!(await crypto.subtle.verify("RSASSA-PKCS1-v1_5", key, bytes(sig), new TextEncoder().encode(`${h}.${p}`)))) return null;
		const claims = decode(p);
		if (claims.iss !== ISSUER || !env.EOS_CLIENT_ID || claims.aud !== env.EOS_CLIENT_ID || claims.pfpid !== env.EOS_PRODUCT_ID) return null;
		if (typeof claims.exp !== "number" || claims.exp < Date.now() / 1000) return null;
		return typeof claims.sub === "string" && claims.sub !== "" ? claims.sub : null;
	} catch {
		return null;
	}
}
