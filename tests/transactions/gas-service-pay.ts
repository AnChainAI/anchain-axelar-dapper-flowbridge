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
    destinationChain: String,
    destinationAddress: String,
    payloadHash: [UInt8],
    gasFeeAmount: UFix64,
    refundAddress: Address
) {
    var tempVault:@FungibleToken.Vault
    let signerAddress: Address

    prepare(signer: AuthAccount) {
        let vaultRef = signer.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow owner's vault reference")
        self.signerAddress = signer.address
        self.tempVault <- vaultRef.withdraw(amount: gasFeeAmount)
    }

    execute{
        if isExpress {
            AxelarGasService.payNativeGasForExpressCall(
                sender: self.signerAddress,
                senderVault: <-self.tempVault,
                destinationChain: destinationChain,
                destinationAddress: destinationAddress,
                payloadHash: payloadHash,
                refundAddress: refundAddress
            )
        } else {
            AxelarGasService.payNativeGasForContractCall(
                sender: self.signerAddress,
                senderVault: <-self.tempVault,
                destinationChain: destinationChain,
                destinationAddress: destinationAddress,
                payloadHash: payloadHash,
                refundAddress: refundAddress
            )
        }
    }
}
  `

export interface PublishCapabilityArgs {
  readonly gasAddress: string
  readonly isExpress: boolean
  readonly destinationChain: string
  readonly destinationAddress: string
  readonly payloadHash: number[]
  readonly gasFeeAmount: any
  readonly refundAddress: string
}

export async function gasServicePay(
  params: TransactionFunctionParams<PublishCapabilityArgs>
) {
  return await sendTransaction({
    cadence: CODE(params.args.gasAddress, params.constants),
    args: (arg, t) => [
      arg(params.args.isExpress, t.Bool),
      arg(params.args.destinationChain, t.String),
      arg(params.args.destinationAddress, t.String),
      arg(
        params.args.payloadHash.map((n) => n.toString()),
        t.Array(t.UInt8)
      ),
      arg(params.args.gasFeeAmount, t.UFix64),
      arg(params.args.refundAddress, t.Address),
    ],
    authorizations: [params.authz],
    payer: params.authz,
    proposer: params.authz,
    limit: 9999,
  })
}
