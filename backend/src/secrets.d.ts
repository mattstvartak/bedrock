// secrets set with `wrangler secret put`, not generated into worker-configuration.d.ts
interface Env {
	JWT_SIGNING_KEY: string;
	STEAM_WEB_API_KEY?: string;
}
