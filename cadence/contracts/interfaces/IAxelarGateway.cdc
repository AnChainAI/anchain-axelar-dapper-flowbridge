pub contract interface IAxelarGateway {
  pub resource AxelarGatewayManager {
    pub fun validateContractCall(
      commandId: String,
      sourceChain: String,
      sourceAddress: String,
      senderAddress: Address,
      payloadHash: String
    ): Bool
  }
}