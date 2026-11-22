import js from '@eslint/js'
import eslintPluginPrettierRecommended from 'eslint-plugin-prettier/recommended'
import reactHooks from 'eslint-plugin-react-hooks'
import reactRefresh from 'eslint-plugin-react-refresh'
import globals from 'globals'
import tseslint from 'typescript-eslint'

export default tseslint.config(
  { ignores: ['dist', 'node_modules', 'coverage'] },
  {
    extends: [
      js.configs.recommended,
      ...tseslint.configs.recommended,
      eslintPluginPrettierRecommended,
    ],
    files: ['**/*.{ts,tsx}'],
    languageOptions: {
      ecmaVersion: 2020,
      globals: globals.browser,
    },
    plugins: {
      'react-hooks': reactHooks,
      'react-refresh': reactRefresh,
    },
    rules: {
      ...reactHooks.configs.recommended.rules,
      'react-refresh/only-export-components': ['warn', { allowConstantExport: true }],
      'no-restricted-imports': [
        'error',
        { patterns: [{ group: ['../*'], message: 'Use the @/ alias, not ../../.' }] },
      ],
    },
  },
  {
    // A route file exports the route object and its component by design.
    files: ['src/routes/**/*.{ts,tsx}'],
    rules: { 'react-refresh/only-export-components': 'off' },
  },
  {
    // The data path is loaders only; an effect here is the mistake this repo exists to prevent.
    files: ['src/routes/**/*.{ts,tsx}', 'src/api/**/*.ts', 'src/loaders/**/*.ts'],
    rules: {
      'no-restricted-imports': [
        'error',
        {
          patterns: [{ group: ['../*'], message: 'Use the @/ alias, not ../../.' }],
          paths: [
            {
              name: 'react',
              importNames: ['useEffect', 'useLayoutEffect'],
              message: 'Data enters through a route loader, not an effect.',
            },
          ],
        },
      ],
      'no-restricted-syntax': [
        'error',
        {
          selector: "MemberExpression[object.name='React'][property.name=/^use(Layout)?Effect$/]",
          message: 'Data enters through a route loader, not an effect.',
        },
      ],
    },
  },
)
