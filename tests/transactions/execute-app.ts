import {
  TransactionFunctionParams,
  sendTransaction,
  FlowConstants,
} from '../../utils/flow'

const CODE = (constants: FlowConstants) => `
import AxelarGateway from ${constants.FLOW_ADMIN_ADDRESS}

transaction(commandId: String, sourceChain: String, sourceAddress: String, contractAddress: String, payload: [UInt8]) {
  execute{
    AxelarGateway.executeApp(commandId: commandId, sourceChain: sourceChain, sourceAddress: sourceAddress, contractAddress: contractAddress, payload: payload)
  }
}
`

export interface ExecuteAppArgs {
  readonly commandId: string
  readonly sourceChain: string
  readonly sourceAddress: string
  readonly contractAddress: string
  readonly payload: number[]
}

export async function executeApp(
  params: TransactionFunctionParams<ExecuteAppArgs>,
) {
  return await sendTransaction({
    cadence: CODE(params.constants),
    args: (arg, t) => [
      arg(params.args.commandId, t.String),
      arg(params.args.sourceChain, t.String),
      arg(params.args.sourceAddress, t.String),
      arg(params.args.contractAddress, t.String),
      arg(
        params.args.payload.map((n) => n.toString()),
        t.Array(t.UInt8),
      ),
    ],
    authorizations: [],
    payer: params.authz,
    proposer: params.authz,
    limit: 9999,
  })
}
