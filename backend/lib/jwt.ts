import jwt from "jsonwebtoken";

const SECRET = process.env.JWT_SIGNING_KEY!;

// Sessions are short-ish lived; the client re-auths silently via platform SSO.
export function mintSession(accountId: string): string {
  return jwt.sign({ sub: accountId }, SECRET, { expiresIn: "30d" });
}

export function verifySession(token: string): string | null {
  try {
    return (jwt.verify(token, SECRET) as { sub: string }).sub;
  } catch {
    return null;
  }
}
