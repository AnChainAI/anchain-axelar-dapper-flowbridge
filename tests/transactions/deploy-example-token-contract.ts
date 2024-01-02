import { TransactionFunctionParams, sendTransaction } from '../../utils/flow'

const CODE = `
transaction(
  contractName: String,
  contractCode: String,
) {
  prepare(signer: AuthAccount) {
    if !signer.contracts.names.contains(contractName) {
      signer.contracts.add(
        name: contractName, 
        code: contractCode.decodeHex(),
        tokenName: "Axelar Fungible Token",
        tokenSymbol: "AXL",
      )
    }
  }
}
`

export interface DeployTokenTemplateArgs {
  readonly contractName: string
  readonly contractCode: string
}

export async function deployTokenTemplate(
  params: Omit<TransactionFunctionParams<DeployTokenTemplateArgs>, 'constants'>
) {
  return await sendTransaction({
    cadence: CODE,
    args: (arg, t) => [
      arg(params.args.contractName, t.String),
      arg(Buffer.from(params.args.contractCode).toString('hex'), t.String),
    ],
    authorizations: [params.authz],
    payer: params.authz,
    proposer: params.authz,
    limit: 9999,
  })
}
