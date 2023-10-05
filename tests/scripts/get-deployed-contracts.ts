import { ScriptFunctionParams, sendScript } from '../../utils/flow'

const CODE = `
pub fun main(address: Address): [String] {
  return getAccount(address).contracts.names
}
`

export interface GetDeployedContractsArgs {
  readonly address: string
}

export async function getDeployedContracts(
  params: Omit<ScriptFunctionParams<GetDeployedContractsArgs>, 'constants'>,
) {
  return await sendScript<string[]>({
    cadence: CODE,
    args: (arg, t) => [arg(params.args.address, t.Address)],
  })
}
