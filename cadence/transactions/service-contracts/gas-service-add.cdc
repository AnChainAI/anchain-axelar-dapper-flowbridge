import AxelarGasService from "../services/AxelarGasService"
import FungibleToken from "fungible-token"
import FlowToken from "FlowToken"

transaction(
    isExpress: Bool,
    senderVault: @FungibleToken.Vault,
    destinationChain: String,
    destinationAddress: String,
    payloadHash: [UInt8],
    gasFeeAmount: UInt256,
    refundAddress: Address
) {
    prepare(signer: AuthAccount) {

        if isExpress {
            AxelarGasService.addNativeExpressGas(
                sender: signer.address,
                senderVault: <-senderVault,
                destinationChain: destinationChain,
                destinationAddress: destinationAddress,
                payloadHash: payloadHash,
                gasFeeAmount: gasFeeAmount,
                refundAddress: refundAddress
            )
        } else {
            AxelarGasService.addNativeGas(
                sender: signer.address,
                senderVault: <-senderVault,
                destinationChain: destinationChain,
                destinationAddress: destinationAddress,
                payloadHash: payloadHash,
                gasFeeAmount: gasFeeAmount,
                refundAddress: refundAddress
            )
        }
    }
}
