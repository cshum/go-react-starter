import { describe, expect, it } from 'vitest'

import fixture from '../../../testdata/asset.json'

describe('Asset wire shape', () => {
  it('matches the fields the API returns', () => {
    expect(Object.keys(fixture).sort()).toEqual(
      ['createdAt', 'filename', 'id', 'sha256', 'size'].sort(),
    )
  })
})
