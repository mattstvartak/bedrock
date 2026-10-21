import { generateKeyPairSync } from "node:crypto";
import { cloudflareTest } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

// A stand-in for Epic's signing key, so tests can mint EOS ID tokens the Worker accepts.
const { publicKey, privateKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
const kid = "test-key";

export default defineConfig({
	plugins: [
		cloudflareTest({
			wrangler: { configPath: "./wrangler.jsonc" },
			miniflare: {
				bindings: {
					JWT_SIGNING_KEY: "test-signing-key",
					STEAM_WEB_API_KEY: "test-key",
					EOS_CLIENT_ID: "test-client",
					EOS_PRODUCT_ID: "test-product",
					EOS_JWKS: JSON.stringify({ keys: [{ ...publicKey.export({ format: "jwk" }), kid }] }),
					TEST_EOS_PRIVATE_JWK: JSON.stringify({ ...privateKey.export({ format: "jwk" }), kid }),
				},
			},
		}),
	],
});
