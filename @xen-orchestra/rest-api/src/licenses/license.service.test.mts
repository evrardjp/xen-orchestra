import assert from 'node:assert/strict'
import { it } from 'node:test'

import { LicenseService } from './license.service.mjs'
import type { RestApi } from '../rest-api/rest-api.mjs'

it('does not query appliance XOSTOR licenses in source edition', async () => {
  const restApi = {
    getXapiObject: () => assert.fail('XAPI objects must not be queried'),
    xoApp: {
      getLicenses: () => assert.fail('appliance licenses must not be queried'),
      isSourceEdition: () => true,
    },
  } as unknown as RestApi

  assert.deepEqual(await new LicenseService(restApi).getXostorLicenses('sr-id'), [])
})
