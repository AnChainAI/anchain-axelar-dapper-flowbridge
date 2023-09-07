import AxelarGateway from "../AxelarGateway.cdc"

pub contract interface IAxelarExecutable {
  pub fun gateway(): &AxelarGateway.AxelarGatewayManager

  pub fun execute(
    commandId: String,
    sourceChain: String,
    sourceAddress: String,
    senderAddress: Address,
    payload: String
  )
}
