import AxelarGasService from "../services/AxelarGasService"
import FungibleToken from "fungible-token"
import FlowToken from "FlowToken"

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