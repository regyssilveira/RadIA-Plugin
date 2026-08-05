module.exports = [
  {
    ignores: [
      "**/node_modules/**",
      "**/vendor/**",
      "**/*.min.js",
      "eslint.config.js"
    ]
  },
  {
    files: ["**/*.js"],
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "script",
      globals: {
        window: "readonly",
        document: "readonly",
        console: "readonly",
        setTimeout: "readonly",
        clearTimeout: "readonly",
        setInterval: "readonly",
        clearInterval: "readonly",
        Event: "readonly",
        MutationObserver: "readonly",
        marked: "readonly",
        Prism: "readonly",
        confirm: "readonly",
        navigator: "readonly",
        chrome: "readonly",
        module: "readonly",
        require: "readonly",
        RadIAAgentDiff: "readonly",
        RadIAAgentGit: "readonly"
      }
    },
    rules: {
      "no-undef": "error",
      "no-unused-vars": ["warn", { "vars": "all", "args": "none" }],
      "no-redeclare": "error",
      "no-const-assign": "error"
    }
  }
];
