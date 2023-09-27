import IAxelarGateway from "./interfaces/IAxelarGateway.cdc"
import EternalStorage from "./util/EternalStorage.cdc"
import Crypto

pub contract AxelarGateway: IAxelarGateway {
    priv let PREFIX_CONTRACT_CALL_APPROVED: [UInt8]
    priv let PREFIX_COMMAND_EXECUTED: [UInt8]

    priv let SELECTOR_APPROVE_CONTRACT_CALL: [UInt8]
    priv let SELECTOR_TRANSFER_OPERATORSHIP: [UInt8]

    // EVENTS
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
        contractAddress: Address,
        payloadHash: [UInt8],
        sourceTxHash: String,
        sourceEventIndex: UInt256
    )

    pub event OperatorshipTransferred(newOperatorsData: String)

    // PUBLIC METHODS
    pub fun callContract(sender: Address, destinationChain: String, contractAddress: String, payload: [UInt8]) {
        emit ContractCall(
            sender: sender,
            destinationChain: destinationChain,
            destinationContractAddress: contractAddress,
            payloadHash: Crypto.hash(payload, algorithm: HashAlgorithm.KECCAK_256),
            payload: payload
        )
    }

    pub fun isContractCallApproved(commandId: String, sourceChain: String, sourceAddress: String, contractAddress: Address, payloadHash: [UInt8]): Bool {
        let key = self._getIsContractCallApprovedKey(commandId: commandId, sourceChain: sourceChain, sourceAddress: sourceAddress, contractAddress: contractAddress, payloadHash: payloadHash)
        return EternalStorage.getBool(key: key)
    }

    pub fun validateContractCall(commandId: String, sourceChain: String, sourceAddress: String, senderAddress: String, payloadHash: [UInt8]): Bool {
        let key = self._getIsContractCallApprovedKey(commandId: commandId, sourceChain: sourceChain, sourceAddress: sourceAddress, contractAddress: senderAddress, payloadHash: payloadHash)
        let valid = EternalStorage.getBool(key: key)
        if valid == true {
            EternalStorage._setBool(key: key, value: false)
        }
        return valid
    }

    // GETTERS
    pub fun isCommandExecuted(commandId: String): Bool {
        return EternalStorage.getBool(key: self._getIsCommandExecutedKey(commandId))
    }

    // EXTERNAL FUNCTIONS
    pub fun execute(
        chainId: UInt256,
        commandIds: [String],
        commands: [String],
        params: [[String]],
        messageHash: [UInt8],
        operators: [String],
        weights: [UInt256],
        threshold: UInt256,
        signatures: [String]
    ) {
        // TODO
    }

    // INTERNAL FUNCTIONS
    priv fun _getIsCommandExecutedKey(_ commandId: String): String {
        return String.encodeHex(self.PREFIX_COMMAND_EXECUTED.concat(commandId.utf8))
    }

    priv fun _getIsContractCallApprovedKey(commandId: String, sourceChain: String, sourceAddress: String, contractAddress: String, payloadHash: [UInt8]): String {
        let data = self.PREFIX_CONTRACT_CALL_APPROVED.concat(commandId.utf8).concat(sourceChain.utf8).concat(sourceAddress.utf8).concat(contractAddress.utf8).concat(payloadHash)
        return String.encodeHex(data)
    }

    init() {
        self.PREFIX_CONTRACT_CALL_APPROVED = "contract-call-approved".utf8
        self.PREFIX_COMMAND_EXECUTED = "command-executed".utf8
        
        self.SELECTOR_TRANSFER_OPERATORSHIP = "transferOperatorship".utf8
        self.SELECTOR_APPROVE_CONTRACT_CALL = "approveContractCall".utf8
    }
}