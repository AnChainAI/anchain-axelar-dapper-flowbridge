import IAxelarExecutable from "../interfaces/IAxelarExecutable.cdc"
import AxelarGateway from "../AxelarGateway.cdc"
import Crypto

pub contract AxelarExecutable: IAxelarExecutable {
  pub let gatewayManager: @AxelarGateway.AxelarGatewayManager

  pub fun gateway(): &AxelarGateway.AxelarGatewayManager {
    return &self.gatewayManager as &AxelarGateway.AxelarGatewayManager
  }

  // @dev Execute an interchain contract call after validating that an approval for it is recorded at the gateway
  pub fun execute(commandId: String, sourceChain: String, sourceAddress: String, senderAddress: Address, payload: String) {
    let payloadHash = String.encodeHex(Crypto.hash(payload.utf8, algorithm: HashAlgorithm.KECCAK_256))

    if (!self.gatewayManager.validateContractCall(commandId: commandId, sourceChain: sourceChain, sourceAddress: sourceAddress, senderAddress: senderAddress, payloadHash: payloadHash)) {
      panic("Not Approved By Gateway")
    }

    self._execute(sourceChain: sourceChain, sourceAddress: sourceAddress, payload: payload)
  }

  // @dev To be overridden by the app
  pub fun _execute(sourceChain: String, sourceAddress: String, payload: String) {}

  init(gatewayManager: @AxelarGateway.AxelarGatewayManager) {
    self.gatewayManager <- gatewayManager
  }
}