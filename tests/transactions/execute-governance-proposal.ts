import {
    TransactionFunctionParams,
    sendTransaction,
    FlowConstants,
  } from '../../utils/flow'
  
  const CODE = (address: string) => `
  import AxelarGovernanceService from ${address}
  
  transaction(proposedCode: String, target: Address, contractName: String) {
    prepare(acct: AuthAccount) {}
    execute{
      AxelarGovernanceService.executeProposal(proposedCode: proposedCode, target: target, contractName: contractName)
    }
  }
  `
  
  export interface ExecuteAppArgs {
    readonly address: string
    readonly target: string
    readonly proposedCode: string
    readonly contractName: string
  }
  
  export async function executeGovernanceProposal(
    params: TransactionFunctionParams<ExecuteAppArgs>,
  ) {
    return await sendTransaction({
      cadence: CODE(params.args.address),
      args: (arg, t) => [
        arg(params.args.proposedCode, t.String),
        arg(params.args.target, t.Address),
        arg(params.args.contractName, t.String)
        
      ],
      authorizations: [params.authz],
      payer: params.authz,
      proposer: params.authz,
      limit: 9999,
    })
  }
  