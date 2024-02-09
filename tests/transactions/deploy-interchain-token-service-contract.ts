import { TransactionFunctionParams, sendTransaction } from '../../utils/flow'

const CODE = `
transaction(
  contractName: String,
  contractCode: String,
  publicKey: String,
  accountCreationFee: UFix64,
) {
  prepare(signer: AuthAccount) {
    if !signer.contracts.names.contains(contractName) {
      signer.contracts.add(
        name: contractName, 
        code: contractCode.decodeHex(),
        publicKey: publicKey,
        accountCreationFee: accountCreationFee,
      )
    }
  }
}
`

export interface DeployInterchainContractArgs {
  readonly contractName: string
  readonly contractCode: string
  readonly publicKey: string,
  readonly accountCreationFee: number,
}

export async function deployInterchainTokenService(
  params: Omit<TransactionFunctionParams<DeployInterchainContractArgs>, 'constants'>
) {
  return await sendTransaction({
    cadence: CODE,
    args: (arg, t) => [
      arg(params.args.contractName, t.String),
      arg(Buffer.from(params.args.contractCode).toString('hex'), t.String),
      arg(params.args.publicKey, t.String),
      arg(params.args.accountCreationFee, t.UFix64),
    ],
    authorizations: [params.authz],
    payer: params.authz,
    proposer: params.authz,
    limit: 9999,
  })
}
