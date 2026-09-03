import baseConfig from '../../eslint.base.config.js';
import pluginQuasar from '@quasar/app-vite/eslint';
import globals from 'globals';

export default [
  ...baseConfig,
  ...pluginQuasar.configs.recommended(),
  {
    languageOptions: {
      globals: {
        ga: 'readonly',
        cordova: 'readonly',
        Capacitor: 'readonly',
        chrome: 'readonly',
        browser: 'readonly',
      },
    },
  },
  {
    files: ['src-pwa/custom-service-worker.ts'],
    languageOptions: {
      globals: {
        ...globals.serviceworker,
      },
    },
  },
];
