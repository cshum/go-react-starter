const UNITS = ['KB', 'MB', 'GB', 'TB'] as const

/** Human readable byte size: 512 -> "512 B", 1536 -> "1.5 KB". */
export function formatBytes(bytes: number): string {
  if (!Number.isFinite(bytes) || bytes < 0) return '—'
  if (bytes < 1024) return `${Math.round(bytes)} B`

  let value = bytes / 1024
  let unit = 0
  while (value >= 1024 && unit < UNITS.length - 1) {
    value /= 1024
    unit += 1
  }
  return `${Math.round(value * 10) / 10} ${UNITS[unit]}`
}

/** Shortens a hash for display: 64 chars -> "9f86d081…". */
export function shortHash(hash: string, length = 8): string {
  return hash.length <= length ? hash : `${hash.slice(0, length)}…`
}
