import { cloudflareTest } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

export default defineConfig({
	plugins: [
		cloudflareTest({
			wrangler: { configPath: "./wrangler.jsonc" },
			miniflare: {
				bindings: {
					JWT_SIGNING_KEY: "test-signing-key",
					STEAM_WEB_API_KEY: "test-key",
					EOS_CLIENT_ID: "test-eos-client",
					EOS_DEPLOYMENT_ID: "test-deployment",
					ALLOW_UNVERIFIED_DEVICE_TOKENS: "1",
				},
			},
		}),
	],
});
