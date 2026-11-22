import { describe, expect, it } from 'vitest'

import { formatBytes, shortHash } from '@/lib/format'

describe('formatBytes', () => {
  it('keeps small sizes in bytes', () => {
    expect(formatBytes(0)).toBe('0 B')
    expect(formatBytes(512)).toBe('512 B')
  })

  it('scales to the largest sensible unit', () => {
    expect(formatBytes(1536)).toBe('1.5 KB')
    expect(formatBytes(1024 * 1024)).toBe('1 MB')
    expect(formatBytes(5 * 1024 * 1024)).toBe('5 MB')
  })

  it('returns a dash for invalid input', () => {
    expect(formatBytes(-1)).toBe('—')
    expect(formatBytes(Number.NaN)).toBe('—')
  })
})

describe('shortHash', () => {
  it('truncates long hashes', () => {
    expect(shortHash('9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08')).toBe(
      '9f86d081…',
    )
  })

  it('leaves short hashes alone', () => {
    expect(shortHash('abc')).toBe('abc')
  })
})
