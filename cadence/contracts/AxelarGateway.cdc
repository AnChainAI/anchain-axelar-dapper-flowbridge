import IAxelarGateway from "./interfaces/IAxelarGateway.cdc"
import AxelarAuthWeighted from "./auth/AxelarAuthWeighted.cdc"
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
        let data = commandIds
        data.appendAll(commands)
        // Is there a way to concat all these params and turn it into a hex encoded string?
        let message: String = "String encoded hex of `chainId`, `commandIds`, `commands`, and `params`"
        //TODO: Message Hash
        let messageHash: String = ""

        let allowOperatorshipTransfer = AxelarAuthWeighted.validateProof(message: message, operators: operators, weights: weights, threshold: threshold, signatures: signatures)
        //Add ChainId check?? is there a way to fetch the chain in the contract?
         //if (chainId != block.chainid) revert InvalidChainId();

         let commandsLength = commandIds.length
         
         if(commandsLength != commandIds.length || commandsLength != params.length){
            panic("Invalid Commands")
         }

         var i = 0

         while i < commandsLength{
            let commandId = commandIds[i]
            if (self.isCommandExecuted(commandId: commandId)){
                continue
            }
            /*
            bytes4 commandSelector;
            bytes32 commandHash = keccak256(abi.encodePacked(commands[i]));

            if (commandHash == SELECTOR_APPROVE_CONTRACT_CALL) {
                commandSelector = AxelarGateway.approveContractCall.selector;
            } else if (commandHash == SELECTOR_TRANSFER_OPERATORSHIP) {
                if (!allowOperatorshipTransfer) continue;

                allowOperatorshipTransfer = false;
                commandSelector = AxelarGateway.transferOperatorship.selector;
            } else {
                continue; Ignore if unknown command received 
            }
            */

            self._setCommandExecuted(commandId: commandId, executed: true)       

            let success : Bool = true
            //call functions

            if (success) {
                emit Executed(commandId: commandId)
            }else{
                self._setCommandExecuted(commandId: commandId, executed: false)
            }
            i = i + 1
         }
    }
    // SELF FUNCTIONS
    priv fun approveContractCall(sourceChain: String, sourceAddress: String, contractAddress: Address, payloadHash: [UInt8], sourceTxHash: String, sourceEventIndex: UInt256, commandId: String){
        self._setContractCalApproved(commandId: commandId, sourceChain: sourceChain, sourceAddress: sourceAddress, contractAddress: contractAddress, payloadHash: payloadHash)
        emit ContractCallApproved(
        commandId: commandId,
        sourceChain: sourceChain,
        sourceAddress: sourceAddress,
        contractAddress: contractAddress,
        payloadHash: payloadHash,
        sourceTxHash: sourceTxHash,
        sourceEventIndex: sourceEventIndex
    )
    }

    // INTERNAL FUNCTIONS
    priv fun _getIsCommandExecutedKey(_ commandId: String): String {
        return String.encodeHex(self.PREFIX_COMMAND_EXECUTED.concat(commandId.utf8))
    }

    priv fun _getIsContractCallApprovedKey(commandId: String, sourceChain: String, sourceAddress: String, contractAddress: Address, payloadHash: [UInt8]): String {
        let data = self.PREFIX_CONTRACT_CALL_APPROVED.concat(commandId.utf8).concat(sourceChain.utf8).concat(sourceAddress.utf8).concat(contractAddress.toString().utf8).concat(payloadHash)
        return String.encodeHex(data)
    }

    // INTERNAL SETTERS
    priv fun _setContractCalApproved(commandId:String, sourceChain: String, sourceAddress:String, contractAddress: Address, payloadHash: [UInt8]){
        EternalStorage._setBool(key:self._getIsContractCallApprovedKey(commandId: commandId, sourceChain: sourceChain, sourceAddress: sourceAddress, contractAddress: contractAddress, payloadHash: payloadHash) , value: true)
    }

    priv fun _setCommandExecuted(commandId: String, executed: bool){
        EternalStorage._setBool(key: self._getIsCommandExecutedKey(commandId: commandId), value: executed)
    }

    init() {
        self.PREFIX_CONTRACT_CALL_APPROVED = "contract-call-approved".utf8
        self.PREFIX_COMMAND_EXECUTED = "command-executed".utf8
        
        self.SELECTOR_TRANSFER_OPERATORSHIP = "transferOperatorship".utf8
        self.SELECTOR_APPROVE_CONTRACT_CALL = "approveContractCall".utf8
    }
}