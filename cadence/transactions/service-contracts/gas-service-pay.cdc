import AxelarGasService from "../services/AxelarGasService"
import FungibleToken from "fungible-token"

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
        let gasService = AxelarGasService(address: 0xAXELARGASSERVICEADDRESS)

        if isExpress {
            gasService.payNativeGasForExpressCall(
                sender: signer.address,
                senderVault: <-senderVault,
                destinationChain: destinationChain,
                destinationAddress: destinationAddress,
                payloadHash: payloadHash,
                gasFeeAmount: gasFeeAmount,
                refundAddress: refundAddress
            )
        } else {
            gasService.payNativeGasForContractCall(
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
