import { TransactionFunctionParams, sendTransaction } from '../../utils/flow'

const CODE = `
transaction(
  contractName: String,
  contractCode: String,
  recentOperatorsSet: [[String]],
  recentWeightsSet: [[UInt256]],
  recentThresholdSet: [UInt256]
) {
  prepare(signer: AuthAccount) {
    if !signer.contracts.names.contains(contractName) {
      signer.contracts.add(
        name: contractName, 
        code: contractCode.decodeHex(),
        recentOperatorsSet: recentOperatorsSet,
        recentWeightsSet: recentWeightsSet,
        recentThresholdSet: recentThresholdSet
      )
    }
  }
}
`

export interface DeployAuthContractArgs {
  readonly contractName: string
  readonly contractCode: string
  readonly recentOperatorsSet: string[][]
  readonly recentWeightsSet: number[][]
  readonly recentThresholdSet: number[]
}

export async function deployAuthContract(
  params: Omit<TransactionFunctionParams<DeployAuthContractArgs>, 'constants'>,
) {
  return await sendTransaction({
    cadence: CODE,
    args: (arg, t) => [
      arg(params.args.contractName, t.String),
      arg(Buffer.from(params.args.contractCode).toString('hex'), t.String),
      arg(
        params.args.recentOperatorsSet,
        t.Array(params.args.recentOperatorsSet.map(() => t.Array(t.String))),
      ),
      arg(
        params.args.recentWeightsSet.map((set) => set.map((n) => n.toString())),
        t.Array(params.args.recentWeightsSet.map(() => t.Array(t.UInt256))),
      ),
      arg(
        params.args.recentThresholdSet.map((n) => n.toString()),
        t.Array(t.UInt256),
      ),
    ],
    authorizations: [params.authz],
    payer: params.authz,
    proposer: params.authz,
    limit: 9999,
  })
}
