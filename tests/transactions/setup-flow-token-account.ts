import { constants } from 'buffer'
import {
  TransactionFunctionParams,
  sendTransaction,
  FlowConstants,
} from '../../utils/flow'

const CODE = (constants: FlowConstants) => `
import FungibleToken from ${constants.FLOW_FT_ADDRESS}
import FlowToken from ${constants.FLOW_TOKEN_ADDRESS}

transaction {

    prepare(signer: AuthAccount) {

        if signer.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault) == nil {
            // Create a new flowToken Vault and put it in storage
            signer.save(<-FlowToken.createEmptyVault(), to: /storage/flowTokenVault)

            // Create a public capability to the Vault that only exposes
            // the deposit function through the Receiver interface
            signer.link<&FlowToken.Vault{FungibleToken.Receiver}>(
                /public/flowTokenReceiver,
                target: /storage/flowTokenVault
            )

            // Create a public capability to the Vault that only exposes
            // the balance field through the Balance interface
            signer.link<&FlowToken.Vault{FungibleToken.Balance}>(
                /public/flowTokenBalance,
                target: /storage/flowTokenVault
            )
        }
    }
}
  `

export interface SetupFlowtokenAccountArgs {
}

export async function setupFlowAccount(
  params: TransactionFunctionParams<SetupFlowtokenAccountArgs>
) {
  return await sendTransaction({
    cadence: CODE(params.constants),
    args: (arg, t) => [
      
    ],
    authorizations: [params.authz],
    payer: params.authz,
    proposer: params.authz,
    limit: 9999,
  })
}
