import { AccountOpts } from './interfaces/account-opts.interface'
import { BaseAccount } from './interfaces/base-account.interface'
import { encodePublicKey, generateKeys } from './keys'
import { createAccount } from './transactions/setup'
import { getAuthorizer } from './auth'

export class FlowAccount {
  private readonly privKey: string
  private readonly address: string

  private constructor(args: BaseAccount) {
    this.privKey = args.privKey
    this.address = args.address
  }

  public static async from(
    opts?: AccountOpts,
    cb?: (account: FlowAccount) => Promise<FlowAccount>,
  ) {
    const account = await FlowAccount.create(opts)
    return cb != null ? await cb(account) : account
  }

  private static async create(opts?: AccountOpts) {
    const keyDuo = generateKeys()
    const pubKey = encodePublicKey(keyDuo.publicKey)
    const result = await createAccount({ key: pubKey, ...opts })
    for (const event of result.events) {
      if (event.type === 'flow.AccountCreated') {
        const ev = event as { data: { address: string } }
        return new this({
          privKey: keyDuo.privateKey,
          address: ev.data.address,
        })
      }
    }
    throw new Error('Address not found')
  }

  public get authz() {
    return getAuthorizer({
      keyIndex: 0,
      address: this.address,
      privKey: this.privKey,
    })
  }

  public get addr() {
    return this.address
  }
}
