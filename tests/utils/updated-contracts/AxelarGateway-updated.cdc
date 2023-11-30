import AxelarAuthWeighted from 0x439b896aa7a8888e
import AddressUtils from 0xf8d6e0586b0a20c7
import Crypto

// Main GateWay contract for audit
access(all) contract AxelarGateway {
  access(self) let SELECTOR_APPROVE_CONTRACT_CALL: [UInt8]
  access(self) let SELECTOR_TRANSFER_OPERATORSHIP: [UInt8]
  access(all) let PREFIX_APP_CAPABILITY_NAME: String

  access(all) resource CGPCommand {
    access(all) var commandId: String
    access(all) var isExecuted: Bool

    init(commandId: String) {
      self.commandId = commandId
      self.isExecuted = false
    }
  }

  /**********\
  |* Events *|
  \**********/
  access(all) event ContractCall(
    sender: Address,
    destinationChain: String,
    destinationContractAddress: String,
    payloadHash: String,
    payload: [UInt8]
  )

  access(all) event Executed(commandId: String)

  access(all) event ContractCallApproved(
    commandId: String,
    sourceChain: String,
    sourceAddress: String,
    contractAddress: String,
    payloadHash: String,
    sourceTxHash: String,
    sourceEventIndex: UInt256
  )

  access(all) struct ApproveContractCallParams {
    pub let sourceChain: String
    pub let sourceAddress: String
    pub let contractAddress: String
    pub let payloadHash: String
    pub let sourceTxHash: String
    pub let sourceEventIndex: UInt256

    init(
      sourceChain: String,
      sourceAddress: String,
      contractAddress: String,
      payloadHash: String,
      sourceTxHash: String,
      sourceEventIndex: UInt256,
    ) {
      self.sourceChain = sourceChain
      self.sourceAddress = sourceAddress
      self.contractAddress = contractAddress
      self.payloadHash = payloadHash
      self.sourceTxHash = sourceTxHash
      self.sourceEventIndex = sourceEventIndex
    }
  }

  access(all) struct ExecutionStatus {
    access(all) let isExecuted: Bool
    access(all) let statusCode: UInt64
    access(all) let errorMessage: String

    init(
      isExecuted: Bool,
      statusCode: UInt64,
      errorMessage: String
    ) {
      self.isExecuted = isExecuted
      self.statusCode = statusCode
      self.errorMessage = errorMessage
    }
  }

  access(self) let executedCommands: {String: ExecutionStatus}
  access(self) let approvedCommands: @{String: CGPCommand}

  init() {        
    self.SELECTOR_TRANSFER_OPERATORSHIP = Crypto.hash("transferOperatorship".utf8, algorithm: HashAlgorithm.KECCAK_256)
    self.SELECTOR_APPROVE_CONTRACT_CALL = Crypto.hash("approveContractCall".utf8, algorithm: HashAlgorithm.KECCAK_256)
    self.PREFIX_APP_CAPABILITY_NAME = "AppCapabilityPath"

    self.executedCommands = {}
    self.approvedCommands <- {}
  }

  access(all) struct ParamHandler {
    access(all) let rawParams: [AnyStruct]

    init(params: [AnyStruct]) {
      self.rawParams = params
    }

    access(contract) fun generateApproveContractCallParams(): ApproveContractCallParams? {
      let sourceChain = self.rawParams[0].isInstance(Type<String>())
      let sourceAddress = self.rawParams[1].isInstance(Type<String>())
      let contractAddress = self.rawParams[2].isInstance(Type<String>())
      let payloadHash = self.rawParams[3].isInstance(Type<String>())
      let sourceTxHash = self.rawParams[4].isInstance(Type<String>())
      let sourceEventIndex = self.rawParams[5].isInstance(Type<UInt256>())

      if !sourceChain || !sourceAddress || !contractAddress || !payloadHash || !sourceTxHash || !sourceEventIndex {
        return nil
      }

      return ApproveContractCallParams(
        sourceChain : self.rawParams[0] as! String,
        sourceAddress : self.rawParams[1] as! String,
        contractAddress : self.rawParams[2] as! String,
        payloadHash : self.rawParams[3] as! String,
        sourceTxHash : self.rawParams[4] as! String,
        sourceEventIndex : self.rawParams[5] as! UInt256,
      )
    }

    access(contract) fun generateTransferOperatorshipParams(): AxelarAuthWeighted.TransferOperatorshipParams? {
      let newOperators = self.rawParams[0].isInstance(Type<[String]>())
      let newWeights = self.rawParams[1].isInstance(Type<[UInt256]>())
      let newThreshold = self.rawParams[2].isInstance(Type<UInt256>())

      if !newOperators || !newWeights || !newThreshold {
        return nil
      }

      return AxelarAuthWeighted.TransferOperatorshipParams(
        newOperators : self.rawParams[0] as! [String],
        newWeights : self.rawParams[1] as! [UInt256],
        newThreshold : self.rawParams[2] as! UInt256,
      )
    }
  }

  access(all) resource interface Executable {
    access(all) fun executeApp(commandResource: &AxelarGateway.CGPCommand, sourceChain: String, sourceAddress: String, payload: [UInt8]): ExecutionStatus
  }

  access(all) resource interface SenderIdentity {}

  access(all) fun callContract(senderIdentity: Capability<&{AxelarGateway.SenderIdentity}>, destinationChain: String, destinationContractAddress: String, payload: [UInt8]) {
    pre {
      senderIdentity.check() && senderIdentity.borrow()!.owner != nil: "Cannot borrow reference to SenderIdentity capability"
    }

    emit ContractCall(
      sender: senderIdentity.address,
      destinationChain: destinationChain,
      destinationContractAddress: destinationContractAddress,
      payloadHash: String.encodeHex(Crypto.hash(payload, algorithm: HashAlgorithm.KECCAK_256)),
      payload: payload
    )
  }

  access(all) fun getCommandExecutionStatus(commandId: String): ExecutionStatus? {
    return self.executedCommands[commandId]
  }

  access(all) fun isCommandApproved(commandId: String): Bool {
    return self.approvedCommands[commandId] != nil ? true : false
  }

  access(all) fun isCommandExecuted(commandId: String): Bool {
    return self.executedCommands[commandId]?.isExecuted ?? false
  }

  access(all) fun execute(
    commandIds: [String],
    commands: [String],
    params: [[AnyStruct]],
    operators: [String],
    weights: [UInt256],
    threshold: UInt256,
    signatures: [String]
  ) {
    let encodedMessage = self.convertDataToHexEncodedMessage(commandIds: commandIds, commands: commands, params: params)

    var allowOperatorshipTransfer = AxelarAuthWeighted.validateProof(message: encodedMessage, operators: operators, weights: weights, threshold: threshold, signatures: signatures)

    let commandsLength = commandIds.length
      
    if (commandsLength != commands.length || commandsLength != params.length) {
      panic("Invalid Commands")
    }

    var i = 0

    while i < commandsLength {
      var commandId = commandIds[i]

      // Skip if commandId is already executed
      if (self.isCommandExecuted(commandId: commandId)) {
        continue
      }

      let commandHash = Crypto.hash(commands[i].utf8, algorithm: HashAlgorithm.KECCAK_256)
      let paramHandler = ParamHandler(params: params[i])

      // Transfer OperatorShip is the only command that is directly processed by this contract - unlike other commannds
      // it is used for managing gateway operators for the Axelar CGP protocol
      if (commandHash == self.SELECTOR_TRANSFER_OPERATORSHIP && params[i].length == 3) {

        if (allowOperatorshipTransfer.isValid) {
          var transferOperatorShipParams = paramHandler.generateTransferOperatorshipParams()

          if transferOperatorShipParams != nil {

            self.executedCommands.insert(
              key: commandId,
              ExecutionStatus( 
                isExecuted: true,
                statusCode: 0,
                errorMessage: ""
              )
            )
            // we only need to track this was executed, since there's no other processing for this command
            let transferStatus = AxelarAuthWeighted.transferOperatorship(message: encodedMessage, operators: operators, weights: weights, threshold: threshold, signatures: signatures, params: transferOperatorShipParams!)
            if transferStatus.isTransferred {
              emit Executed(commandId: commandId)
            } else {
              self.executedCommands.insert(
                key: commandId,
                ExecutionStatus( 
                  isExecuted: false,
                  statusCode: transferStatus.statusCode,
                  errorMessage: transferStatus.errorMessage
                )
              )
            }
          }
        }
      } else if (commandHash == self.SELECTOR_APPROVE_CONTRACT_CALL && params[i].length == 6) {
        let approveContractCallParams = paramHandler.generateApproveContractCallParams()

        if approveContractCallParams != nil {
          // store the CGPCommand Resource for later use
          let oldCgpCommand <- self.approvedCommands[commandId] <- create CGPCommand(commandId: commandId)

          emit ContractCallApproved (
            commandId: commandId,
            sourceChain: approveContractCallParams!.sourceChain,
            sourceAddress: approveContractCallParams!.sourceAddress,
            contractAddress: approveContractCallParams!.contractAddress,
            payloadHash: approveContractCallParams!.payloadHash,
            sourceTxHash: approveContractCallParams!.sourceTxHash,
            sourceEventIndex: approveContractCallParams!.sourceEventIndex
          )

          self.destroyCGPCommand(cgpCommand: <- oldCgpCommand)
        }
      } else {
        continue
      }

      i = i + 1
    }
  }

  access(all) fun executeApp(commandId: String, sourceChain: String, sourceAddress: String, contractAddress: String, payload: [UInt8]): Bool {
    // Check to see if command id has already been executed
    if (self.isCommandExecuted(commandId: commandId)) {
      panic("Command id: ".concat(commandId).concat(" is already executed"))
    }

    // Check to see if command is approved
    if !self.isCommandApproved(commandId: commandId) {
      panic("Command with id: ".concat(commandId).concat(" is not approved"))
    }

    // Validate that contract address string is a valid address for current network
    let address = self.parseAddressForCurrentNetwork(contractAddress)

    // Verify that the executable capability exists for that contract address
    let capabilityPath = self.getAppCapabilityStoragePath(address) ?? panic("Could not get app capability path for address ".concat(address.toString()))
    var appCapability: &Capability<&{AxelarGateway.Executable}>? = self.account.borrow<&Capability<&{AxelarGateway.Executable}>>(from: capabilityPath)
    if appCapability?.check() != true {
      appCapability = self.claimAppCapability(provider: address)
    }
    if appCapability == nil || !appCapability!.check() {
      panic("Cannot retrieve app executable capability")
    }

    // Get a reference to the CGPCommand resource to pass into the executable method
    let cgpCommand = (&self.approvedCommands[commandId] as &CGPCommand?) ?? panic("Could not borrow reference to CGP Command")

    // Call the execute method from the dApp
    let executionStatus = appCapability!.borrow()!.executeApp(commandResource: cgpCommand, sourceChain: sourceChain, sourceAddress: sourceAddress, payload: payload)

    // Record command execution
    self.executedCommands.insert(
      key: commandId,
      executionStatus
    )

    // If the execute method is called successfully,
    // remove the cgp command resource and destroy the resource
    if executionStatus.isExecuted {
      self.destroyCGPCommand(cgpCommand: <- self.approvedCommands.remove(key: commandId))
    }

    return executionStatus.isExecuted
  }

  access(all) fun getAppCapabilityStoragePath(_ address: Address): StoragePath? {
    return StoragePath(identifier: self.PREFIX_APP_CAPABILITY_NAME.concat(address.toString()))
  }

  access(self) fun destroyCGPCommand(cgpCommand: @CGPCommand?) {
    let commandId = cgpCommand?.commandId
    destroy cgpCommand
    if commandId != nil {
      emit Executed(commandId: commandId!)
    }
  }

  access(self) fun convertDataToHexEncodedMessage(commandIds: [String], commands: [String], params: [[AnyStruct]]): String {
    let message: [UInt8] = []

    for id in commandIds {
      message.appendAll(id.utf8)
    }

    for command in commands {
      message.appendAll(command.utf8)
    }

    for inputs in params {
      message.appendAll(self.convertInputsToUtf8(inputs))
    }

    return String.encodeHex(message)
  }

  access(self) fun convertInputsToUtf8(_ inputs: [AnyStruct]): [UInt8] {
    let convertedInput: [UInt8] = []

    for input in inputs {
      if input.isInstance(Type<String>()) {
        let stringInput = input as! String
        convertedInput.appendAll(stringInput.utf8)
        continue
      }
      if input.isInstance(Type<UInt256>()) {
        let uint256Input = input as! UInt256
        convertedInput.appendAll(uint256Input.toString().utf8)
        continue
      }
      if input.isInstance(Type<[AnyStruct]>()) {
        let anyStructArrayInput = input as! [AnyStruct]
        convertedInput.appendAll(self.convertInputsToUtf8(anyStructArrayInput))
      }
    }

    return convertedInput
  }

  access(self) fun claimAppCapability(provider: Address): &Capability<&{AxelarGateway.Executable}>? {
    if let appCapability = self.account.inbox.claim<&{AxelarGateway.Executable}>(self.PREFIX_APP_CAPABILITY_NAME.concat(provider.toString()), provider: provider) {
      let capabilityPath = self.getAppCapabilityStoragePath(provider) ?? panic("Could not get app capability path for address ".concat(provider.toString()))
      let oldCapability = self.account.load<Capability<&{AxelarGateway.Executable}>>(from: capabilityPath)
      self.account.save(appCapability, to: capabilityPath)
      return self.account.borrow<&Capability<&{AxelarGateway.Executable}>>(from: capabilityPath)
    }
    
    return nil
  }

  access(self) fun parseAddressForCurrentNetwork(_ address: String): Address {
    let currentNetwork = AddressUtils.currentNetwork()
    if AddressUtils.isValidAddress(address, forNetwork: currentNetwork) {
      let parsedAddress = AddressUtils.parseAddress(address)
      if parsedAddress != nil {
        return parsedAddress!
      } else {
        panic("Could not parse address")
      }
    }

    panic("Invalid Address")
  }
  pub fun updated(): Bool{
    return true
  }
}