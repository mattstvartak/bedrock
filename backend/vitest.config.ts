import { cloudflareTest } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

export default defineConfig({
	plugins: [cloudflareTest({ wrangler: { configPath: "./wrangler.jsonc" }, miniflare: { bindings: { JWT_SIGNING_KEY: "test-signing-key", STEAM_WEB_API_KEY: "test-key" } } })],
});
