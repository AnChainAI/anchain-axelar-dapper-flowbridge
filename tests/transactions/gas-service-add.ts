import { constants } from 'buffer'
import {
  TransactionFunctionParams,
  sendTransaction,
  FlowConstants,
} from '../../utils/flow'

const CODE = (address: string, constants: FlowConstants) => `
  import AxelarGasService from ${address}
  import FlowToken from ${constants.FLOW_TOKEN_ADDRESS}
  import FungibleToken from ${constants.FLOW_FT_ADDRESS}

  transaction(
    isExpress: Bool,
    txHash: String,
    logIndex: UInt256,
    gasFeeAmount: UFix64,
    refundAddress: Address
) {
    var tempVault: @FungibleToken.Vault
    prepare(signer: AuthAccount) {
        let vaultRef = signer.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's vault")
        self.tempVault <- vaultRef.withdraw(amount: gasFeeAmount)
        
    }

    execute {
        if isExpress {
            AxelarGasService.addNativeExpressGas(
                txHash: txHash,
                senderVault: <-self.tempVault,
                logIndex: logIndex,
                gasFeeAmount: gasFeeAmount,
                refundAddress: refundAddress
            )
        } else {
            AxelarGasService.addNativeGas(
                txHash: txHash,
                senderVault: <-self.tempVault,
                logIndex: logIndex,
                gasFeeAmount: gasFeeAmount,
                refundAddress: refundAddress
            )
        }
    }
}

  `

export interface PublishCapabilityArgs {
  readonly gasAddress: string
  readonly isExpress: boolean
  readonly txHash: string
  readonly logIndex: number
  readonly gasFeeAmount: any
  readonly refundAddress: string
}

export async function gasServiceAdd(
  params: TransactionFunctionParams<PublishCapabilityArgs>
) {
  return await sendTransaction({
    cadence: CODE(params.args.gasAddress, params.constants),
    args: (arg, t) => [
      arg(params.args.isExpress, t.Bool),
      arg(params.args.txHash, t.String),
      arg(params.args.logIndex, t.UInt256),
      arg(params.args.gasFeeAmount, t.UFix64),
      arg(params.args.refundAddress, t.Address),
    ],
    authorizations: [params.authz],
    payer: params.authz,
    proposer: params.authz,
    limit: 9999,
  })
}
