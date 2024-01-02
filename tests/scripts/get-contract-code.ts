import { ScriptFunctionParams, sendScript } from '../../utils/flow'

const CODE = `
pub fun main(address: Address, name: String): [UInt8] {
  return getAccount(address).contracts.get(name: name)?.code!
}
`

export interface GetDeployedContractsArgs {
  readonly address: string
  readonly name: string
}

export async function getContractCode(
  params: Omit<ScriptFunctionParams<GetDeployedContractsArgs>, 'constants'>,
) {
  return await sendScript<string[]>({
    cadence: CODE,
    args: (arg, t) => [arg(params.args.address, t.Address), arg(params.args.name, t.String)],
  })
}
