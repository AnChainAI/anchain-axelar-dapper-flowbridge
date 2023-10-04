pub contract interface IAxelarExecutable {
  pub resource interface AxelarExecutable {
    pub fun execute(sourceChain: String, sourceAddress: String, payload: [UInt8])
  }
}