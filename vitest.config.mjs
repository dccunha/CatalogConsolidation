import { defineConfig } from "vitest/config"

export default defineConfig({
  test: {
    environment: "jsdom",
    include: ["spec/javascript/**/*.test.js"],
    coverage: {
      provider: "v8",
      include: ["app/javascript/**/*.js", "app/views/pwa/service-worker.js"],
      reportsDirectory: "coverage/js",
      reporter: ["text-summary", "html"]
    }
  }
})
