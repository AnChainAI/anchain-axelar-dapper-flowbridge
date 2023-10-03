pub contract interface IAxelarExecutable {
  pub resource AxelarExecutable {
    pub fun execute(sourceChain: String, sourceAddress: String, payload: [UInt8])
  }
}
