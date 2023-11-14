import { wrapInputParams } from '../utils/wrap-input-params'
import {
  TransactionFunctionParams,
  sendTransaction,
  FlowConstants,
} from '../../utils/flow'

const CODE = (constants: FlowConstants) => `
import AxelarGateway from ${constants.FLOW_ADMIN_ADDRESS}

transaction(
  commandIds: [String],
  commands: [String],
  params: [[AnyStruct]],
  operators: [String],
  weights: [UInt256],
  threshold: UInt256,
  signatures: [String]
) {
  prepare(acct: AuthAccount) {}
  execute {
    AxelarGateway.execute(commandIds: commandIds, commands: commands, params: params, operators: operators, weights: weights, threshold: threshold, signatures: signatures)
  }
}
`

export interface ExecuteArgs {
  readonly commandIds: string[]
  readonly commands: string[]
  readonly params: (string | string[])[][]
  readonly operators: string[]
  readonly weights: number[]
  readonly threshold: number
  readonly signatures: string[]
}

export async function execute(params: TransactionFunctionParams<ExecuteArgs>) {
  return await sendTransaction({
    cadence: CODE(params.constants),
    args: (arg, t) => {
      const { datas, types } = wrapInputParams(params.args.params)
      return [
        arg(params.args.commandIds, t.Array(t.String)),
        arg(params.args.commands, t.Array(t.String)),
        arg(datas, t.Array(types)),
        arg(params.args.operators, t.Array(t.String)),
        arg(
          params.args.weights.map((n) => n.toString()),
          t.Array(t.UInt256),
        ),
        arg(params.args.threshold.toString(), t.UInt256),
        arg(params.args.signatures, t.Array(t.String)),
      ]
    },
    authorizations: [params.authz],
    payer: params.authz,
    proposer: params.authz,
    limit: 9999,
  })
}
