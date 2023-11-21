import AxelarGasService from "../services/AxelarGasService"
import FungibleToken from "fungible-token"
import FlowToken from "flow-token"

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
                gasFeeAmount: gasFeeAmount,
                refundAddress: refundAddress
            )
        } else {
            AxelarGasService.payNativeGasForContractCall(
                sender: self.signerAddress,
                senderVault: <-self.tempVault,
                destinationChain: destinationChain,
                destinationAddress: destinationAddress,
                payloadHash: payloadHash,
                gasFeeAmount: gasFeeAmount,
                refundAddress: refundAddress
            )
        }
    }
}
