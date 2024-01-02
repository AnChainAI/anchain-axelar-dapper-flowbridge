import { TransactionFunctionParams, sendTransaction } from '../../utils/flow'

const CODE = `
transaction(
  contractName: String,
  contractCode: String,
  gateway: Address,
  governanceChain: String,
  governanceAddress: String,
  minimumTimeDealy: UInt64,
) {
  prepare(signer: AuthAccount) {
    if !signer.contracts.names.contains(contractName) {
      signer.contracts.add(
        name: contractName, 
        code: contractCode.decodeHex(),
        gateway: gateway,
        governanceChain: governanceChain,
        governanceAddress: governanceAddress,
        minimumTimeDealy: minimumTimeDealy,
      )
    }
  }
}
`

export interface DeployGovernanceContractArgs {
  readonly contractName: string
  readonly contractCode: string
  readonly gateway: string,
  readonly governanceChain: string,
  readonly governanceAddress: string,
  readonly minimumTimeDelay: number,
}

export async function deployGovernanceContract(
  params: Omit<TransactionFunctionParams<DeployGovernanceContractArgs>, 'constants'>
) {
  return await sendTransaction({
    cadence: CODE,
    args: (arg, t) => [
      arg(params.args.contractName, t.String),
      arg(Buffer.from(params.args.contractCode).toString('hex'), t.String),
      arg(params.args.gateway, t.Address),
      arg(params.args.governanceChain, t.String),
      arg(params.args.governanceAddress, t.String),
      arg(params.args.minimumTimeDelay.toString(), t.UInt64),
    ],
    authorizations: [params.authz],
    payer: params.authz,
    proposer: params.authz,
    limit: 9999,
  })
}
