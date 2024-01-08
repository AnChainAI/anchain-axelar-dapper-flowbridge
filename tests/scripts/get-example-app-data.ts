import { ScriptFunctionParams, sendScript } from '../../utils/flow'

const CODE = (address: string) => `
import ExampleApplication from ${address}

access(all) fun main(commandId: String): ExampleApplication.GMPData {
  let data = ExampleApplication.getApprovedCommand(commandId: commandId)
  if (data == nil) {
    return ExampleApplication.GMPData(sourceChain: "", sourceAddress: "", payload: [])
  }
  return data!
}
`

export interface GetApprovedCommandDataArgs {
  readonly address: string
  readonly commandId: string
}

export interface GMPData {
  readonly sourceChain: string
  readonly sourceAddress: string
  readonly payload: string[]
}

export async function getApprovedCommandData(
  params: Omit<ScriptFunctionParams<GetApprovedCommandDataArgs>, 'constants'>,
) {
  return await sendScript<GMPData>({
    cadence: CODE(params.args.address),
    args: (arg, t) => [arg(params.args.commandId, t.String)],
  })
}
