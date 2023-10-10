import { TransactionFunctionParams, sendTransaction } from '../../utils/flow'

const CODE = `
transaction(
  contractName: String,
  contractCode: String,
  recentOperators: [String],
  recentWeights: [UInt256],
  recentThreshold: UInt256
) {
  prepare(signer: AuthAccount) {
    if !signer.contracts.names.contains(contractName) {
      signer.contracts.add(
        name: contractName, 
        code: contractCode.decodeHex(),
        recentOperators: recentOperators,
        recentWeights: recentWeights,
        recentThreshold: recentThreshold
      )
    }
  }
}
`

export interface DeployAuthContractArgs {
  readonly contractName: string
  readonly contractCode: string
  readonly recentOperators: string[]
  readonly recentWeights: number[]
  readonly recentThreshold: number
}

export async function deployAuthContract(
  params: Omit<TransactionFunctionParams<DeployAuthContractArgs>, 'constants'>,
) {
  return await sendTransaction({
    cadence: CODE,
    args: (arg, t) => [
      arg(params.args.contractName, t.String),
      arg(Buffer.from(params.args.contractCode).toString('hex'), t.String),
      arg(params.args.recentOperators, t.Array(t.String)),
      arg(
        params.args.recentWeights.map((n) => n.toString()),
        t.Array(t.UInt256),
      ),
      arg(params.args.recentThreshold.toString(), t.UInt256),
    ],
    authorizations: [params.authz],
    payer: params.authz,
    proposer: params.authz,
    limit: 9999,
  })
}
