import AxelarGasService from "../services/AxelarGasService"
import FungibleToken from "fungible-token"
import FlowToken from "flow-token"

transaction(
    isExpress: Bool,
    destinationChain: String,
    destinationAddress: String,
    payloadHash: [UInt8],
    gasFeeAmount: UInt256,
    refundAddress: Address
) {
    let tempValut = @FlowToken.Vault

    prepare(signer: AuthAccount) {
        let vaultRef = signer.borrow<&FlowToken.Vault>(from: storage/flowTokenVault)
            ?? panic("Could not borrow owner's vault reference")

        self.temporaryVault <- vaultRef.withdraw(amount: gasFeeAmount)
    }

    execute{
        if isExpress {
            AxelarGasService.payNativeGasForExpressCall(
                sender: signer.address,
                senderVault: <-self.temporaryVault,
                destinationChain: destinationChain,
                destinationAddress: destinationAddress,
                payloadHash: payloadHash,
                gasFeeAmount: gasFeeAmount,
                refundAddress: refundAddress
            )
        } else {
            AxelarGasService.payNativeGasForContractCall(
                sender: signer.address,
                senderVault: <-self.temporaryVault,
                destinationChain: destinationChain,
                destinationAddress: destinationAddress,
                payloadHash: payloadHash,
                gasFeeAmount: gasFeeAmount,
                refundAddress: refundAddress
            )
        }
    }
}
