import IAxelarGasService from "../interfaces/IAxelarGasService.cdc"
import FungibleToken from "fungible-token"
import FlowToken from "flow-token"

// Reverence Solidity Implementation: https://github.com/axelarnetwork/axelar-cgp-solidity/blob/main/contracts/gas-service/AxelarGasService.sol
pub contract AxelarGasService: IAxelarGasService {
    pub event NativeGasPaidForContractCall(
        sourceAddress: Address,
        destinationChain: String,
        destinationAddress: String,
        payloadHash: [UInt8],
        gasFeeAmount: UInt256,
        refundAddress: Address,
    )

    pub event NativeGasPaidForExpressCall(
        sourceAddress: Address,
        destinationChain: String,
        destinationAddress: String,
        payloadHash: [UInt8],
        gasFeeAmount: UInt256,
        refundAddress: Address,
    )

    pub event NativeGasAdded(
        txHash: String,
        logIndex: UInt256,
        gasFeeAmount: UInt256,
        refundAddress: Address,
    )

    pub event NativeExpressGasAdded(
        txHash: String,
        logIndex: UInt256,
        gasFeeAmount: UInt256,
        refundAddress: Address,
    )

    pub event Refund(
        txHash: String,
        logIndex: UInt256,
        reciever: Address,
        token: String, //potentially not needed
        amount: UInt256,
    )

    access(all) fun payNativeGasForContractCall(
        sender: Address,
        senderVault: @FungibleToken.Vault,
        destinationChain: String,
        destinationAddress: String,
        payloadHash: [UInt8],
        gasFeeAmount: UInt256,
        refundAddress: Address,
    ) {
        let paymentVault = self.account.borrow<&FlowToken.Vault>(from: /storage/FlowVault)
            ?? panic("Could not borrow reference to the FlowToken vault")
        paymentVault.deposit(from: <-senderVault, amount: gasFeeAmount)

        emit NativeGasPaidForContractCall(
            sourceAddress: sender,
            destinationChain: destinationChain,
            destinationAddress: destinationAddress,
            payloadHash: payloadHash,
            gasFeeAmount: gasFeeAmount,
            refundAddress: refundAddress,
        )
    }

    access(all) fun payNativeGasForExpressCall(
        sender: Address,
        senderVault: @FungibleToken.Vault,
        destinationChain: String,
        destinationAddress: String,
        payloadHash: [UInt8],
        gasFeeAmount: UInt256,
        refundAddress: Address,
    ) {
        let paymentVault = self.account.borrow<&FlowToken.Vault>(from: /storage/FlowVault)
            ?? panic("Could not borrow reference to the FlowToken vault")
        paymentVault.deposit(from: <-senderVault, amount: gasFeeAmount)

        emit NativeGasPaidForExpressCall(
            sourceAddress: sender,
            destinationChain: destinationChain,
            destinationAddress: destinationAddress,
            payloadHash: payloadHash,
            gasFeeAmount: gasFeeAmount,
            refundAddress: refundAddress,
        )
    }

    access(all) fun addNativeGas(
        txHash: String,
        logIndex: UInt256,
        gasFeeAmount: UInt256,
        refundAddress: Address,
    ) {
        let paymentVault = self.account.borrow<&FlowToken.Vault>(from: /storage/FlowVault)
            ?? panic("Could not borrow reference to the FlowToken vault")
        paymentVault.deposit(amount: gasFeeAmount)

        emit NativeGasAdded(
            txHash: txHash,
            logIndex: logIndex,
            gasFeeAmount: gasFeeAmount,
            refundAddress: refundAddress,
        )
    }

    access(all) fun addNativeExpressGas(
        txHash: String,
        logIndex: UInt256,
        gasFeeAmount: UInt256,
        refundAddress: Address,
    ) {
        let paymentVault = self.account.borrow<&FlowToken.Vault>(from: /storage/FlowVault)
            ?? panic("Could not borrow reference to the FlowToken vault")
        paymentVault.deposit(amount: gasFeeAmount)

        emit NativeExpressGasAdded(
            txHash: txHash,
            logIndex: logIndex,
            gasFeeAmount: gasFeeAmount,
            refundAddress: refundAddress,
        )
    }

    access(account) fun collectFees(
        vault: @FungibleToken.Vault,
        amount: UInt256,
    ){
        let paymentVault = self.account.borrow<&FlowToken.Vault>(from: /storage/FlowVault)
            ?? panic("Could not borrow reference to the FlowToken vault")
        paymentVault.withdraw(amount: amount)
        vault.deposit(from: <-paymentVault, amount: amount)
    }
    
}