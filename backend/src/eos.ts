// EOS Connect id tokens are RS256 JWTs signed by Epic. A real token carries
// iss https://api.epicgames.dev/auth/v1/oauth, aud = the EOS client id,
// sub = the product user id, pfdid = the deployment id, and expires an hour
// after issue. Keys come from Epic's JWKS and are cached in the isolate.
import { fromB64url } from "./jwt";

const ISSUER = "https://api.epicgames.dev/auth/v1/oauth";
const JWKS_URL = "https://api.epicgames.dev/auth/v1/oauth/jwks";
const JWKS_TTL_MS = 60 * 60 * 1000;
const JWKS_MIN_REFETCH_MS = 60 * 1000;

const decodeJson = (s: string) => JSON.parse(new TextDecoder().decode(fromB64url(s)));

type Jwk = JsonWebKey & { kid?: string };
let jwks: { keys: Jwk[]; fetched: number } | null = null;

async function keyFor(kid: string, refresh: boolean): Promise<Jwk | null> {
	const age = jwks ? Date.now() - jwks.fetched : Infinity;
	if (age > JWKS_TTL_MS || (refresh && age > JWKS_MIN_REFETCH_MS)) {
		const res = await fetch(JWKS_URL);
		if (!res.ok) return null;
		jwks = { keys: ((await res.json()) as { keys: Jwk[] }).keys, fetched: Date.now() };
	}
	return jwks?.keys.find((k) => k.kid === kid) ?? null;
}

// The PUID the token was issued for, or null when it fails any check.
export async function verifyEosIdToken(env: Env, token: string): Promise<string | null> {
	if (!env.EOS_CLIENT_ID) return null;
	try {
		const [head, body, sig] = token.split(".");
		const header = decodeJson(head) as { alg?: string; kid?: string };
		if (header.alg !== "RS256" || !header.kid) return null;
		// An unknown kid can mean Epic rotated keys, so look once more with a fresh set.
		const jwk = (await keyFor(header.kid, false)) ?? (await keyFor(header.kid, true));
		if (!jwk) return null;
		const key = await crypto.subtle.importKey("jwk", jwk, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
		const ok = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", key, fromB64url(sig), new TextEncoder().encode(`${head}.${body}`));
		if (!ok) return null;
		const c = decodeJson(body) as { iss?: string; aud?: string; sub?: string; exp?: number; pfdid?: string };
		if (c.iss !== ISSUER || c.aud !== env.EOS_CLIENT_ID || !c.sub || !c.exp || c.exp < Date.now() / 1000) return null;
		if (env.EOS_DEPLOYMENT_ID && c.pfdid !== env.EOS_DEPLOYMENT_ID) return null;
		return c.sub;
	} catch {
		return null;
	}
}
