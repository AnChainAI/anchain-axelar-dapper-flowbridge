import {
    TransactionFunctionParams,
    sendTransaction,
    FlowConstants,
  } from '../../utils/flow'
  
  const CODE = (address: string) => `\
    #allowAccountLinking
    import AxelarGovernanceService from ${address}

    transaction(recipient: Address) {
    
    let accountCap: Capability<&AuthAccount>
        prepare(signer: AuthAccount) {
            if !signer.getCapability<&AuthAccount>(AxelarGovernanceService.UpdaterContractAccountPrivatePath).check() {
                signer.unlink(AxelarGovernanceService.UpdaterContractAccountPrivatePath)
                self.accountCap = signer.linkAccount(AxelarGovernanceService.UpdaterContractAccountPrivatePath)
                    ?? panic("Problem linking AuthAccount Capability")
            } else {
                self.accountCap = signer.getCapability<&AuthAccount>(AxelarGovernanceService.UpdaterContractAccountPrivatePath)
            }
            
            assert(self.accountCap.check(), message: "Invalid AuthAccount Capability retrieved")
            
            signer.inbox.publish(
                self.accountCap,
                name: AxelarGovernanceService.inboxHostAccountCapPrefix.concat(signer.address.toString()),
                recipient: recipient
            )
        }
    }
  `
  
  export interface PublishCapabilityArgs {
    readonly address: string
    readonly recipient: string
  }
  
  export async function publishAuthCapabilityToGovernance(
    params: TransactionFunctionParams<PublishCapabilityArgs>,
  ) {
    return await sendTransaction({
      cadence: CODE(params.args.address),
      args: (arg, t) => [arg(params.args.recipient, t.Address)],
      authorizations: [params.authz],
      payer: params.authz,
      proposer: params.authz,
      limit: 9999,
    })
  }
  