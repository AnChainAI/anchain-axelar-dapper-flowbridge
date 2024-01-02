import {
    TransactionFunctionParams,
    sendTransaction,
    FlowConstants,
  } from '../../utils/flow'
  
  const CODE = (address: string) => `
  import AxelarGovernanceService from ${address}
  
  transaction(proposedCode: String, target: Address) {
    prepare(acct: AuthAccount) {}
    execute{
      AxelarGovernanceService.executeProposal(proposedCode: proposedCode, target: target)
    }
  }
  `
  
  export interface ExecuteAppArgs {
    readonly address: string
    readonly target: string
    readonly proposedCode: string
  }
  
  export async function executeGovernanceProposal(
    params: TransactionFunctionParams<ExecuteAppArgs>,
  ) {
    return await sendTransaction({
      cadence: CODE(params.args.address),
      args: (arg, t) => [
        arg(params.args.proposedCode, t.String),
        arg(params.args.target, t.Address),
        
      ],
      authorizations: [params.authz],
      payer: params.authz,
      proposer: params.authz,
      limit: 9999,
    })
  }
  