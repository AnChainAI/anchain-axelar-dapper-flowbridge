import { wrapContracts } from '../../utils/flow/lib/wrappers/contracts.wrapper'
import {
  TransactionFunctionParams,
  ContractDetails,
  sendTransaction,
} from '../../utils/flow'

const CODE = `
transaction(contracts: [{String:String}]) {
  prepare(signer: AuthAccount) {
    for contract in contracts {
      let name = contract["name"] ?? panic("Contract name is required.")
      let code = contract["code"] ?? panic("Contract code is required.")
      if !signer.contracts.names.contains(name) {
        signer.contracts.add(
          name: name, 
          code: code.decodeHex() 
        )
      }
    }
  }
}
`

export interface DeployContractsArgs {
  readonly contracts: ContractDetails[]
}

export async function deployContracts(
  params: TransactionFunctionParams<DeployContractsArgs>,
) {
  let { datas, types } = wrapContracts(params.args.contracts)
  return await sendTransaction({
    cadence: CODE,
    args: (arg, t) => [arg(datas, t.Array(types))],
    authorizations: [params.authz],
    payer: params.authz,
    proposer: params.authz,
    limit: 9999,
  })
}
