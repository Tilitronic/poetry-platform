import baseConfig from '../../eslint.base.config.js';
import pluginQuasar from '@quasar/app-vite/eslint';
import globals from 'globals';
import { defineConfigWithVueTs, vueTsConfigs } from '@vue/eslint-config-typescript';
import prettierSkipFormatting from '@vue/eslint-config-prettier/skip-formatting';

export default defineConfigWithVueTs(
  ...baseConfig,
  pluginQuasar.configs.recommended(),
  vueTsConfigs.recommendedTypeChecked,
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
  prettierSkipFormatting,
);
