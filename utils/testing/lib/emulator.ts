import { countKeys } from './scripts/count-keys'
import { send } from '@onflow/transport-grpc'
import { getAuthorizer } from './auth'
import * as fcl from '@onflow/fcl'

export class Emulator {
  private static readonly PRIVATE_KEY =
    'bb489d388acb91c0b8569cd980535fe1ea33ac84ba471354b83651f8c274a63b'
  private static readonly ADDRESS = '0xf8d6e0586b0a20c7'
  private static readonly URL = 'http://localhost:8080'
  private static MAX_PROPOSER_KEYS = 0

  private constructor() {
    throw new Error('Cannot create an instance of Emulator')
  }

  static async connect() {
    fcl.config({ 'accessNode.api': Emulator.URL, 'sdk.transport': send })
    const result = await countKeys(this.addr)
    if (BigInt(result) > 247) {
      throw new Error(`Too many keys on emulator account: ${result}`)
    }
    Emulator.MAX_PROPOSER_KEYS = parseInt(result, 10)
  }

  static get addr() {
    return Emulator.ADDRESS
  }

  static get url() {
    return Emulator.URL
  }

  static get authz() {
    return getAuthorizer({
      keyIndex: 0,
      address: Emulator.ADDRESS,
      privKey: Emulator.PRIVATE_KEY,
    })
  }

  static get proposer() {
    return getAuthorizer({
      keyIndex: 0,
      address: Emulator.ADDRESS,
      privKey: Emulator.PRIVATE_KEY,
    })
  }
}
