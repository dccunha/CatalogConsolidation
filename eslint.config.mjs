import js from "@eslint/js"
import globals from "globals"

export default [
  js.configs.recommended,
  {
    files: ["app/javascript/**/*.js", "app/views/pwa/**/*.js"],
    languageOptions: {
      globals: { ...globals.browser, ...globals.serviceworker }
    },
    rules: {
      complexity: ["error", 8]
    }
  },
  {
    files: ["spec/javascript/**/*.js"],
    languageOptions: {
      globals: { ...globals.browser, ...globals.node }
    }
  },
  {
    files: ["*.config.mjs"],
    languageOptions: {
      globals: globals.node
    }
  }
]
