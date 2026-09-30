import { defineConfig } from "vitest/config"

export default defineConfig({
  test: {
    environment: "jsdom",
    include: ["spec/javascript/**/*.test.js"],
    coverage: {
      provider: "v8",
      include: ["app/javascript/**/*.js"],
      exclude: [
        "app/javascript/application.js",
        "app/javascript/controllers/application.js",
        "app/javascript/controllers/index.js"
      ],
      reportsDirectory: "coverage/js",
      reporter: ["text-summary", "html"],
      thresholds: {
        perFile: true,
        lines: 80,
        statements: 80,
        functions: 80,
        branches: 70
      }
    }
  }
})
