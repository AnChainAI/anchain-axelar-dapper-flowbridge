pub contract interface IAxelarExecutable {
  pub fun execute(
    commandId: String,
    sourceChain: String,
    sourceAddress: String,
    senderAddress: String,
    payload: [UInt8]
  )
}
