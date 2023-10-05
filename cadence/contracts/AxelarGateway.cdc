import IAxelarExecutable from "./interfaces/IAxelarExecutable.cdc"
import AxelarAuthWeighted from "./auth/AxelarAuthWeighted.cdc"
import EternalStorage from "./util/EternalStorage.cdc"
import Crypto

pub contract AxelarGateway {
    priv let PREFIX_CONTRACT_CALL_APPROVED: [UInt8]
    priv let PREFIX_COMMAND_EXECUTED: [UInt8]

    priv let SELECTOR_APPROVE_CONTRACT_CALL: [UInt8]
    priv let SELECTOR_TRANSFER_OPERATORSHIP: [UInt8]

    /**********\
    |* Events *|
    \**********/
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

    pub struct ApproveContractCallParams {
        pub let sourceChain: String
        pub let sourceAddress: String
        pub let contractAddress: String
        pub let payloadHash: [UInt8]
        pub let sourceTxHash: String
        pub let sourceEventIndex: UInt256
        pub let commandId: String

        init(
            sourceChain: String,
            sourceAddress: String,
            contractAddress: String,
            payloadHash: [UInt8],
            sourceTxHash: String,
            sourceEventIndex: UInt256,
            commandId: String
        ) {
            self.sourceChain = sourceChain
            self.sourceAddress = sourceAddress
            self.contractAddress = contractAddress
            self.payloadHash = payloadHash
            self.sourceTxHash = sourceTxHash
            self.sourceEventIndex = sourceEventIndex
            self.commandId = commandId
        }
    }

    /******************\
    |* Public Methods *|
    \******************/
    pub fun callContract(sender: Address, destinationChain: String, destinationContractAddress: String, payload: [UInt8]) {
        emit ContractCall(
            sender: sender,
            destinationChain: destinationChain,
            destinationContractAddress: destinationContractAddress,
            payloadHash: Crypto.hash(payload, algorithm: HashAlgorithm.KECCAK_256),
            payload: payload
        )
    }

    pub fun isContractCallApproved(commandId: String, sourceChain: String, sourceAddress: String, contractAddress: String, payloadHash: [UInt8]): Bool {
        let key = self._getIsContractCallApprovedKey(commandId: commandId, sourceChain: sourceChain, sourceAddress: sourceAddress, contractAddress: contractAddress, payloadHash: payloadHash)
        return EternalStorage.getBool(key: key)
    }

    pub fun validateContractCall(commandId: String, sourceChain: String, sourceAddress: String, contractAddress: String, payloadHash: [UInt8]): Bool {
        let key = self._getIsContractCallApprovedKey(commandId: commandId, sourceChain: sourceChain, sourceAddress: sourceAddress, contractAddress: contractAddress, payloadHash: payloadHash)
        let valid = EternalStorage.getBool(key: key)
        if valid == true {
            EternalStorage._setBool(key: key, value: false)
        }
        return valid
    }

    /***********\
    |* Getters *|
    \***********/
    pub fun isCommandExecuted(commandId: String): Bool {
        return EternalStorage.getBool(key: self._getIsCommandExecutedKey(commandId))
    }

    /**********************\
    |* External Functions *|
    \**********************/
    pub fun execute(
        commandIds: [String],
        commands: [String],
        params: [[String]],
        operators: [String],
        weights: [UInt256],
        threshold: UInt256,
        signatures: [String]
    ) {
        let message = self._dataToHexEncodedMessage(commandIds: commandIds, commands: commands, params: params)

        var allowOperatorshipTransfer = AxelarAuthWeighted.validateProof(message: message, operators: operators, weights: weights, threshold: threshold, signatures: signatures)

        let commandsLength = commandIds.length
        
        if(commandsLength != commands.length || commandsLength != params.length) {
            panic("Invalid Commands")
        }

        var i = 0

        while i < commandsLength {
            let commandId = commandIds[i]
            if (self.isCommandExecuted(commandId: commandId)) {
                continue
            }

            let commandHash = Crypto.hash(commands[i].utf8, algorithm: HashAlgorithm.KECCAK_256)

            if (commandHash == self.SELECTOR_APPROVE_CONTRACT_CALL && params[i].length == 7) {
                let approveParams = self._getApproveContractCallParams(params: params[i])

                if approveParams != nil {
                    self._setCommandExecuted(commandId: commandId, executed: true)
                    self.approveContractCall(params: approveParams!)
                    emit Executed(commandId: commandId)
                } else {
                    self._setCommandExecuted(commandId: commandId, executed: false)
                }
            } else if (commandHash == self.SELECTOR_TRANSFER_OPERATORSHIP && params[i].length == 3) {
                if (!allowOperatorshipTransfer) {
                    continue
                }

                allowOperatorshipTransfer = false
                let transferParams = self._getTransferOperatorshipParams(params: params[i])
                if transferParams != nil {
                    self._setCommandExecuted(commandId: commandId, executed: true)
                    AxelarAuthWeighted.transferOperatorship(params: transferParams!)
                    emit Executed(commandId: commandId)
                } else {
                    self._setCommandExecuted(commandId: commandId, executed: false)
                }
            } else {
                continue
            }

            i = i + 1
        }
    }

    pub fun executeApp(commandId: String, sourceChain: String, sourceAddress: String, contractAddress: String, payload: [UInt8]) {
        let appCapability = EternalStorage._getCapability(contractAddress: contractAddress)

        if appCapability == nil {
            panic("AxelarExecutable Capability not found for ".concat(contractAddress))
        }

        let payloadHash = Crypto.hash(payload, algorithm: HashAlgorithm.KECCAK_256)

        if (!self.validateContractCall(commandId: commandId, sourceChain: sourceChain, sourceAddress: sourceAddress, contractAddress: contractAddress, payloadHash: payloadHash)) {
            panic("Not approved by gateway")
        }

        let executeCapability = appCapability!.borrow()
        if (executeCapability == nil) {
            panic("Could not borrow execute capability")
        }

        executeCapability!.execute(sourceChain: sourceChain, sourceAddress: sourceAddress, payload: payload)
    }

    pub fun onboardApp(_ executeCapability: Capability<&{IAxelarExecutable.AxelarExecutable}>) {
        pre {
            executeCapability.check(): "Invalid capability"
        }

        EternalStorage._setCapability(capability: executeCapability)
    }

    /******************\
    |* Self Functions *|
    \******************/
    priv fun approveContractCall(params: ApproveContractCallParams) {
        self._setContractCalApproved(commandId: params.commandId, sourceChain: params.sourceChain, sourceAddress: params.sourceAddress, contractAddress: params.contractAddress, payloadHash: params.payloadHash)
        emit ContractCallApproved(
            commandId: params.commandId,
            sourceChain: params.sourceChain,
            sourceAddress: params.sourceAddress,
            contractAddress: params.contractAddress,
            payloadHash: params.payloadHash,
            sourceTxHash: params.sourceTxHash,
            sourceEventIndex: params.sourceEventIndex
        )
    }

    /********************\
    |* Internal Getters *|
    \********************/
    priv fun _getIsCommandExecutedKey(_ commandId: String): String {
        return String.encodeHex(Crypto.hash(self.PREFIX_COMMAND_EXECUTED.concat(commandId.utf8), algorithm: HashAlgorithm.KECCAK_256))
    }

    priv fun _getIsContractCallApprovedKey(commandId: String, sourceChain: String, sourceAddress: String, contractAddress: String, payloadHash: [UInt8]): String {
        let hashedData = Crypto.hash(self.PREFIX_CONTRACT_CALL_APPROVED.concat(commandId.utf8).concat(sourceChain.utf8).concat(sourceAddress.utf8).concat(contractAddress.utf8).concat(payloadHash), algorithm: HashAlgorithm.KECCAK_256)
        return String.encodeHex(hashedData)
    }

    /********************\
    |* Internal Setters *|
    \********************/
    priv fun _setContractCalApproved(commandId:String, sourceChain: String, sourceAddress: String, contractAddress: String, payloadHash: [UInt8]) {
        EternalStorage._setBool(key: self._getIsContractCallApprovedKey(commandId: commandId, sourceChain: sourceChain, sourceAddress: sourceAddress, contractAddress: contractAddress, payloadHash: payloadHash), value: true)
    }

    priv fun _setCommandExecuted(commandId: String, executed: Bool) {
        EternalStorage._setBool(key: self._getIsCommandExecutedKey(commandId), value: executed)
    }

    /**************************\
    |* Internal Functionality *|
    \**************************/
    priv fun _dataToHexEncodedMessage(commandIds: [String], commands: [String], params: [[String]]): String {
        let message: [UInt8] = []

        for id in commandIds {
            message.appendAll(id.utf8)
        }

        for command in commands {
            message.appendAll(command.utf8)
        }

        for inputs in params {
            for input in inputs {
                message.appendAll(input.utf8)
            }
        }

        return String.encodeHex(message)
    }

    priv fun _getApproveContractCallParams(params: [AnyStruct]): ApproveContractCallParams? {
        let sourceChain = params[0].isInstance(Type<String>())
        let sourceAddress = params[1].isInstance(Type<String>())
        let contractAddress = params[2].isInstance(Type<String>())
        let payloadHash = params[3].isInstance(Type<[UInt8]>())
        let sourceTxHash = params[4].isInstance(Type<String>())
        let sourceEventIndex = params[5].isInstance(Type<UInt256>())
        let commandId = params[6].isInstance(Type<String>())

        if !sourceChain || !sourceAddress || !contractAddress || !payloadHash || !sourceTxHash || !sourceEventIndex || !commandId {
            return nil
        }

        return ApproveContractCallParams(
            sourceChain : params[0] as! String,
            sourceAddress : params[1] as! String,
            contractAddress : params[2] as! String,
            payloadHash : params[3] as! [UInt8],
            sourceTxHash : params[4] as! String,
            sourceEventIndex : params[5] as! UInt256,
            commandId : params[6] as! String,
        )
    }

    priv fun _getTransferOperatorshipParams(params: [AnyStruct]): AxelarAuthWeighted.TransferOperatorshipParams? {
        let newOperators = params[0].isInstance(Type<[String]>())
        let newWeights = params[1].isInstance(Type<[UInt256]>())
        let newThreshold = params[2].isInstance(Type<UInt256>())

        if !newOperators || !newWeights || !newThreshold {
            return nil
        }

        return AxelarAuthWeighted.TransferOperatorshipParams(
            newOperators : params[0] as! [String],
            newWeights : params[1] as! [UInt256],
            newThreshold : params[2] as! UInt256,
        )
    }

    init() {
        self.PREFIX_CONTRACT_CALL_APPROVED = Crypto.hash("contract-call-approved".utf8, algorithm: HashAlgorithm.KECCAK_256)
        self.PREFIX_COMMAND_EXECUTED = Crypto.hash("command-executed".utf8, algorithm: HashAlgorithm.KECCAK_256)
        
        self.SELECTOR_TRANSFER_OPERATORSHIP = Crypto.hash("transferOperatorship".utf8, algorithm: HashAlgorithm.KECCAK_256)
        self.SELECTOR_APPROVE_CONTRACT_CALL = Crypto.hash("approveContractCall".utf8, algorithm: HashAlgorithm.KECCAK_256)
    }
}