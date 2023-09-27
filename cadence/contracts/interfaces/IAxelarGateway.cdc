pub contract interface IAxelarGateway {
  pub event ContractCall(
    sender: Address,
    destinationChain: String,
    destinationContractAddress: String,
    payloadHash: [UInt8],
    payload: [UInt8]
  )

  pub event Executed(commandId: String)

  pub event ContractCallApproved(
    commandId: String,
    sourceChain: String,
    sourceAddress: String,
    contractAddress: String,
    payloadHash: [UInt8],
    sourceTxHash: String,
    sourceEventIndex: UInt256
  )

  pub event OperatorshipTransferred(newOperatorsData: String)

  /********************\
  |* Public Functions *|
  \********************/
  pub fun callContract(sender: Address, destinationChain: String, contractAddress: String, payload: [UInt8])

  pub fun isContractCallApproved(
    commandId: String,
    sourceChain: String,
    sourceAddress: String,
    contractAddress: String,
    payloadHash: [UInt8]
  ): Bool

  pub fun validateContractCall(
    commandId: String,
    sourceChain: String,
    sourceAddress: String,
    senderAddress: String,
    payloadHash: [UInt8]
  ): Bool

  /***********\
  |* Getters *|
  \***********/
  pub fun isCommandExecuted(commandId: String): Bool

  /**********************\
  |* External Functions *|
  \**********************/
  pub fun execute(input: String)
}
