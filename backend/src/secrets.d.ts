// secrets set with `wrangler secret put`, not generated into worker-configuration.d.ts
interface Env {
	JWT_SIGNING_KEY: string;
	STEAM_WEB_API_KEY?: string;
	EOS_CLIENT_ID?: string;
	EOS_DEPLOYMENT_ID?: string;
	// "1" accepts unverified device tokens. .dev.vars and tests only.
	ALLOW_UNVERIFIED_DEVICE_TOKENS?: string;
}
