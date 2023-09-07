import IAxelarGateway from "./interfaces/IAxelarGateway.cdc"
import EternalStorage from "./util/EternalStorage.cdc"
import Crypto

pub contract AxelarGateway: IAxelarGateway {
    pub let AxelarGatewayManagerStoragePath: StoragePath

    pub resource AxelarGatewayManager {
        pub fun validateContractCall(
            commandId: String,
            sourceChain: String,
            sourceAddress: String,
            senderAddress: Address,
            payloadHash: String
        ): Bool {
            let key = self._getIsContractCallApprovedKey(commandId: commandId, sourceChain: sourceChain, sourceAddress: sourceAddress, contractAddress: senderAddress, payloadHash: payloadHash)
            let valid = EternalStorage.getBool(key: key)
            return valid
        }

        pub fun _getIsContractCallApprovedKey(
            commandId: String,
            sourceChain: String,
            sourceAddress: String,
            contractAddress: Address,
            payloadHash: String
        ): String {
            let data = commandId.concat(sourceChain.concat(sourceAddress).concat(contractAddress.toString().concat(payloadHash))).utf8
            let key = String.encodeHex(Crypto.hash(data, algorithm: HashAlgorithm.KECCAK_256))
            return key;
        }
    }

    init() {
        self.AxelarGatewayManagerStoragePath = /storage/AxelarGatewayManagerStoragePath
        self.account.save(<- create AxelarGatewayManager(), to: self.AxelarGatewayManagerStoragePath)
    }
}