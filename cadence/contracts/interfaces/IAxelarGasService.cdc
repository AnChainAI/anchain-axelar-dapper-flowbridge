pub contract interface IAxelarGasService {
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

    pub fun payNativeGasForContractCall(
        sender: Address,
        destinationChain: String,
        destinationAddress: String,
        payload: String,
        refundAddress: Address,
    ): Void

    pub fun payNativeGasForExpressCall(
        sender: Address,
        destinationChain: String,
        destinationAddress: String,
        payload: String,
        refundAddress: Address,
    ): Void

    pub fun addNativeGas(
        txHash: String,
        logIndex: UInt256,
        refundAddress: Address,
    ): Void

    pub fun addNativeExpressGas(
        txHash: String,
        logIndex: UInt256,
        refundAddress: Address,
    ): Void

    pub fun collectfees( // modified to only account for native token
        receiver: Address,
        amount: UInt256,
    ): Void

    pub fun refund(
        txHash: String,
        logIndex: UInt256,
        receiver: Address,
        token: String,
        amount: UInt256,
    ): Void

    pub fun gasCollector(): Address
}