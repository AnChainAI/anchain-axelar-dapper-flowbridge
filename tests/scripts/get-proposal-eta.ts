import { ScriptFunctionParams, sendScript } from '../../utils/flow'

const CODE = (address: string) => `
import AxelarGovernanceService from ${address}

pub fun main(proposedCode: String, target: Address, contractName: String): UInt64 {
  let data = AxelarGovernanceService.getProposalEta(proposedCode: proposedCode, target: target, contractName: contractName)
  if (data == nil) {
        return 0
  }
  return data!
}
`

export interface GetApprovedCommandDataArgs {
  readonly address: string
  readonly target: string
  readonly proposedCode: string
  readonly contractName: string
}

export async function getProposalEta(
  params: Omit<ScriptFunctionParams<GetApprovedCommandDataArgs>, 'constants'>
) {
  return await sendScript<number>({
    cadence: CODE(params.args.address),
    args: (arg, t) => [
      arg(params.args.proposedCode, t.String),
      arg(params.args.target, t.Address),
      arg(params.args.contractName, t.String),
    ],
  })
}
