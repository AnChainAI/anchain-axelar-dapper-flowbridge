import { BaseAuthzArgs } from './interfaces/base-authz-args.interface'
import { signWithKey } from './keys'
import * as fcl from '@onflow/fcl'

export function getAuthorizer(
  args: BaseAuthzArgs & { readonly privKey: string },
) {
  return (account: Record<string, unknown> = {}) => {
    const indx = args.keyIndex
    const addr = args.address
    const prvk = args.privKey
    const sign = signWithKey
    return {
      ...account,
      tempId: `${addr}-${indx}`,
      addr: fcl.sansPrefix(addr),
      keyId: Number(indx),
      signingFunction: (signable: { message: string }) => ({
        addr: fcl.withPrefix(addr),
        keyId: Number(indx),
        signature: sign(prvk, signable.message),
      }),
    }
  }
}
