import { AccountOpts } from '../interfaces/account-opts.interface'
import { sendTransaction } from '../../../util-flow'
import { EMULATOR_CONST } from '../constants'
import { Emulator } from '../emulator'

const CODE = `
import FungibleToken from ${EMULATOR_CONST.FLOW_FT_ADDRESS}
import FlowToken from ${EMULATOR_CONST.FLOW_TOKEN_ADDRESS}

transaction(key: String, fundWithFLOW: Bool) {
  let flowTokenReceiver: &{FungibleToken.Receiver}
  let flowTokenAdmin: &FlowToken.Administrator
  let account: AuthAccount
  let amount: UFix64

  prepare(signer: AuthAccount) {
    self.account = AuthAccount(payer: signer)
    self.account.addPublicKey(key.decodeHex())
    self.amount = 1000.0

    self.flowTokenAdmin = signer
      .borrow<&FlowToken.Administrator>(from: /storage/flowTokenAdmin)
      ?? panic("Signer is not the token admin")

    self.flowTokenReceiver = self.account
      .getCapability(/public/flowTokenReceiver)
      .borrow<&{FungibleToken.Receiver}>()
      ?? panic("Unable to borrow receiver reference")
  }

  execute {
    if fundWithFLOW {
      let minter <- self.flowTokenAdmin.createNewMinter(allowedAmount: self.amount)
      let mintedVault <- minter.mintTokens(amount: self.amount)
      self.flowTokenReceiver.deposit(from: <-mintedVault)
      destroy minter
    }
  }
}
`

export interface CreateAccountArgs extends AccountOpts {
  readonly key: string
}

export async function createAccount(args: CreateAccountArgs) {
  return await sendTransaction({
    cadence: CODE,
    args: (arg, t) => [
      arg(args.key, t.String),
      arg(args.fundWithFlow ?? true, t.Bool),
    ],
    authorizations: [Emulator.authz],
    payer: Emulator.authz,
    proposer: Emulator.proposer,
    limit: 9999,
  })
}
