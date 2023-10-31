import AxelarGateway from "../AxelarGateway.cdc"

access(all) contract ExampleApplication {
  access(self) let approvedCommands: {String: GMPData}

  access(all) event CommandApproved(
    commandId: String,
    sourceChain: String,
    sourceAddress: String
  )

  access(all) struct GMPData {
    access(all) let sourceChain: String
    access(all) let sourceAddress: String
    access(all) let payload: [UInt8]
    
    init(sourceChain: String, sourceAddress: String, payload: [UInt8]) {
      self.sourceChain = sourceChain
      self.sourceAddress = sourceAddress
      self.payload = payload
    }
  }

  access(all) resource ExecutableResource: AxelarGateway.Executable {
    access(all) fun executeApp(commandResource: &AxelarGateway.CGPCommand, sourceChain: String, sourceAddress: String, payload: [UInt8]) {
      let gmpData = GMPData(sourceChain: sourceChain, sourceAddress: sourceAddress, payload: payload)
      let commandId = commandResource.commandId
      ExampleApplication.approvedCommands.insert(key: commandId, gmpData)

      emit CommandApproved(commandId: commandId, sourceChain: sourceChain, sourceAddress: sourceAddress)
    }
  }

  access(all) fun getApprovedCommand(commandId: String): GMPData? {
    return self.approvedCommands[commandId]
  }

  init() {
    self.approvedCommands = {}
    let axelarExecutable <- create ExecutableResource()
    self.account.save(<- axelarExecutable, to: /storage/AxelarExecutable)
  }
}