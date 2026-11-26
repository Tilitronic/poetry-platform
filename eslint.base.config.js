import js from '@eslint/js';
import globals from 'globals';
import pluginVue from 'eslint-plugin-vue';
import tseslint from 'typescript-eslint';
import prettierSkipFormatting from '@vue/eslint-config-prettier/skip-formatting';

export default [
  {
    ignores: [
      'apps/api-server/**',
      'packages/analytics-pipeline/**',
      '**/node_modules/**',
      '**/dist/**',
      '**/.quasar/**',
      // Generated code (FlatBuffers/lezer/typegen) is machine-written; lint
      // would only fight the generator.
      '**/generated/**',
    ],
  },

  js.configs.recommended,

  // Spread (not nest) — flat config otherwise keeps the array and ESLint's
  // config-array throws "Unexpected array" when a sub-config is itself a list.
  ...pluginVue.configs['flat/essential'],

  {
    files: ['**/*.ts'],
    plugins: {
      '@typescript-eslint': tseslint.plugin,
    },
    languageOptions: {
      parser: tseslint.parser,
    },
    rules: {
      '@typescript-eslint/consistent-type-imports': ['error', { prefer: 'type-imports' }],
      // TS-aware variant: understands exported enum members, type-only
      // imports, etc. Scaffolds and worker seams use `_`-prefixed params to
      // pin a signature before the body exists — never flag those as dead code.
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
      // js.configs.recommended enables the JS-only rule; it misreads TS
      // constructs (e.g. exported enum members), so disable it for TS.
      'no-unused-vars': 'off',
    },
  },

  // .vue SFCs must keep vue-eslint-parser (from pluginVue) as the top-level
  // parser — setting `parser: tseslint.parser` here would break <template>
  // parsing. Instead delegate only the <script> block to @typescript-eslint so
  // the TS rules above also apply inside SFCs.
  {
    files: ['**/*.vue'],
    plugins: {
      '@typescript-eslint': tseslint.plugin,
    },
    languageOptions: {
      parserOptions: {
        parser: tseslint.parser,
      },
    },
    rules: {
      '@typescript-eslint/consistent-type-imports': ['error', { prefer: 'type-imports' }],
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
      'no-unused-vars': 'off',
    },
  },

  {
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module',
      globals: {
        ...globals.browser,
        ...globals.node,
        process: 'readonly',
      },
    },
    rules: {
      'prefer-promise-reject-errors': 'off',
      'no-debugger': process.env.NODE_ENV === 'production' ? 'error' : 'off',
    },
  },

  prettierSkipFormatting,
];
