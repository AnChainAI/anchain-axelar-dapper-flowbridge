import FlowToken from "FlowToken"
import FungibleToken from "FungibleToken"

// Reverence Solidity Implementation: https://github.com/axelarnetwork/axelar-cgp-solidity/blob/main/contracts/gas-service/AxelarGasService.sol
access(all) contract AxelarGasService {

    access(all) event NativeGasPaidForContractCall(
        sourceAddress: Address,
        destinationChain: String,
        destinationAddress: String,
        payloadHash: [UInt8],
        gasFeeAmount: UFix64,
        refundAddress: Address,
    )

    access(all) event NativeGasPaidForExpressCall(
        sourceAddress: Address,
        destinationChain: String,
        destinationAddress: String,
        payloadHash: [UInt8],
        gasFeeAmount: UFix64,
        refundAddress: Address,
    )

    access(all) event NativeGasAdded(
        txHash: String,
        logIndex: UInt256,
        gasFeeAmount: UFix64,
        refundAddress: Address,
    )

    access(all) event NativeExpressGasAdded(
        txHash: String,
        logIndex: UInt256,
        gasFeeAmount: UFix64,
        refundAddress: Address,
    )

    access(all) event Refund(
        txHash: String,
        logIndex: UInt256,
        reciever: Address,
        token: String, //potentially not needed
        amount: UFix64,
    )

    access(self) fun borrowPaymentVaultAndDeposit(senderVault: @FungibleToken.Vault){
        let vault = self.account.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the FlowToken vault")
        vault.deposit(from: <- senderVault)
    }

    access(all) fun payNativeGasForContractCall(
        sender: Address,
        senderVault: @FungibleToken.Vault,
        destinationChain: String,
        destinationAddress: String,
        payloadHash: [UInt8],
        refundAddress: Address,
    ) {
    pre {
        senderVault.balance > 0.0: "Provided vault is empty"
    }
        let senderVaultBalance = senderVault.balance
        let paymentVault = self.borrowPaymentVaultAndDeposit(senderVault: <- senderVault)

        emit NativeGasPaidForContractCall(
            sourceAddress: sender,
            destinationChain: destinationChain,
            destinationAddress: destinationAddress,
            payloadHash: payloadHash,
            gasFeeAmount: senderVaultBalance,
            refundAddress: refundAddress,
        )

    }

    access(all) fun payNativeGasForExpressCall(
        sender: Address,
        senderVault: @FungibleToken.Vault,
        destinationChain: String,
        destinationAddress: String,
        payloadHash: [UInt8],
        refundAddress: Address,
    ) {
    pre {
        senderVault.balance > 0.0: "Provided vault is empty"
    }
        let senderVaultBalance = senderVault.balance
        let paymentVault = self.borrowPaymentVaultAndDeposit(senderVault: <- senderVault)

        emit NativeGasPaidForExpressCall(
            sourceAddress: sender,
            destinationChain: destinationChain,
            destinationAddress: destinationAddress,
            payloadHash: payloadHash,
            gasFeeAmount: senderVaultBalance,
            refundAddress: refundAddress,
        )
    }

    access(all) fun addNativeGas(
        txHash: String,
        senderVault: @FungibleToken.Vault,
        logIndex: UInt256,
        refundAddress: Address,
    ) {
    pre {
        senderVault.balance > 0.0: "Provided vault is empty"
    }
        let senderVaultBalance = senderVault.balance
        let paymentVault = self.borrowPaymentVaultAndDeposit(senderVault: <- senderVault)

        emit NativeGasAdded(
            txHash: txHash,
            logIndex: logIndex,
            gasFeeAmount: senderVaultBalance,
            refundAddress: refundAddress,
        )
    }

    access(all) fun addNativeExpressGas(
        txHash: String,
        senderVault: @FungibleToken.Vault,
        logIndex: UInt256,
        refundAddress: Address,
    ) {
    pre {
        senderVault.balance > 0.0: "Provided vault is empty"
    }
        let senderVaultBalance = senderVault.balance
        let paymentVault = self.borrowPaymentVaultAndDeposit(senderVault: <- senderVault)

        emit NativeExpressGasAdded(
            txHash: txHash,
            logIndex: logIndex,
            gasFeeAmount: senderVaultBalance,
            refundAddress: refundAddress,
        )
    }

    access(account) fun collectFees(
        receiver: &{FungibleToken.Receiver},
        amount: UFix64,
    ){
        let paymentVault = self.account.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the FlowToken vault")
        let tempVault <- paymentVault.withdraw(amount: amount)
        receiver.deposit(from: <-tempVault)
    }
    
}