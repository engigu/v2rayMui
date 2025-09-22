export type ThemeMode = 'light' | 'dark' | 'system'

const THEME_KEY = 'theme'

export function applyTheme(mode: ThemeMode) {
  const root = document.documentElement
  const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
  const isDark = mode === 'dark' || (mode === 'system' && prefersDark)
  root.classList.toggle('dark', isDark)
}

export function getInitialTheme(): ThemeMode {
  const saved = (localStorage.getItem(THEME_KEY) as ThemeMode | null)
  if (saved === 'light' || saved === 'dark' || saved === 'system') return saved
  return 'system'
}

export function setTheme(mode: ThemeMode) {
  localStorage.setItem(THEME_KEY, mode)
  applyTheme(mode)
}

export { THEME_KEY }


