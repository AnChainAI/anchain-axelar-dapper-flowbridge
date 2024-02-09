import { ScriptFunctionParams, sendScript } from '../../utils/flow'

const CODE = (address: string) => `
import EVM from ${address}

pub fun main(): String {
    let functionCall = EVM.encodeABIWithSignature("multiply(uint256)", [UInt256(6)])
    return "0x".concat(String.encodeHex(functionCall))
}
`

export interface GetApprovedCommandDataArgs {
  readonly address: string
}

export async function testAbiEncode(
  params: Omit<ScriptFunctionParams<GetApprovedCommandDataArgs>, 'constants'>,
) {
  return await sendScript<number>({
    cadence: CODE(params.args.address),
    args: (arg, t) => [],
  })
}
