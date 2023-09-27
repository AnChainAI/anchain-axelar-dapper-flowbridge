import * as fcl from '@onflow/fcl'

// https://docs.onflow.org/cadence/language/accounts/
const CODE = `
pub fun main(address: Address): Int {
  var i = 0
  let account = getAccount(address)
  while account.keys.get(keyIndex: i) != nil {
    i = i + 1
  }
  return i
}
`

export async function countKeys(address: string): Promise<string> {
  return await fcl.query({
    cadence: CODE,
    args: (
      arg: (a: unknown, b: unknown) => unknown,
      t: { Address: () => unknown }
    ) => [arg(address, t.Address)],
  })
}
