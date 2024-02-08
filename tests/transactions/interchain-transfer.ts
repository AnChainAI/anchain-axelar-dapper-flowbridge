import { constants } from 'buffer'
import {
  TransactionFunctionParams,
  sendTransaction,
  FlowConstants,
} from '../../utils/flow'

const CODE = (address: string) => `
  import InterchainTokenService from ${address}

  transaction(
    contractName: String,
    contractAddress: Address,
    destinationChain: String,
    destinationAddress: String,
    amount: UFix64,
    metadata: [UInt8]
  ) {
    prepare(signer: AuthAccount) {
        let senderIdentity = signer.getCapability<&{AxelarGateway.SenderIdentity}>(/public/senderIdentity)
        assert(senderIdentity.borrow() != nil, message: "Missing sender identity capability")

        let vault = signer.borrow<&FungibleToken.Vault>(from: /storage/fungibleTokenVault)
            ?? panic("Could not borrow reference to the owner's vault")
        
        let withdrawVault <- vault.withdraw(amount: amount)

        InterchainTokenService.interchainTransfer(
            senderIdentity: senderIdentity,
            contractName: contractName,
            contractAddress: contractAddress,
            destinationChain: destinationChain,
            destinationAddress: destinationAddress,
            vault: <-withdrawVault,
            metadata: metadata
        )
    }
  }
`

export async function interchainTransfer(params: { contractAddress: unknown; constants: any; contractName: unknown; destinationChain: unknown; destinationAddress: unknown; amount: unknown; metadata: unknown; authz: () => unknown }) {
  return await sendTransaction({
    cadence: CODE(params.contractAddress, params.constants),
    args: (arg, t) => [
      arg(params.contractName, t.String),
      arg(params.contractAddress, t.Address),
      arg(params.destinationChain, t.String),
      arg(params.destinationAddress, t.String),
      arg(params.amount, t.UFix64),
      arg(params.metadata, t.Array(t.UInt8)),
    ],
    authorizations: [params.authz],
    payer: params.authz,
    proposer: params.authz,
  })
}
