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
            let hostPrivatePath = PrivatePath(identifier: "HostAccount_".concat(recipient.toString()))!

            if !signer.getCapability<&AuthAccount>(AxelarGovernanceService.UpdaterContractAccountPrivatePath).check() {
                signer.unlink(AxelarGovernanceService.UpdaterContractAccountPrivatePath)
                self.accountCap = signer.linkAccount(AxelarGovernanceService.UpdaterContractAccountPrivatePath)
                    ?? panic("Problem linking AuthAccount Capability")
            } else {
                self.accountCap = signer.getCapability<&AuthAccount>(AxelarGovernanceService.UpdaterContractAccountPrivatePath)
            }
            
            assert(self.accountCap.check(), message: "Invalid AuthAccount Capability retrieved")

            if signer.type(at: AxelarGovernanceService.HostStoragePath) == nil {
              signer.save(
                  <- AxelarGovernanceService.createNewHost(accountCap: self.accountCap),
                  to: AxelarGovernanceService.HostStoragePath
              )
            }
            if !signer.getCapability<&AxelarGovernanceService.Host>(hostPrivatePath).check() {
                signer.unlink(hostPrivatePath)
                signer.link<&AxelarGovernanceService.Host>(hostPrivatePath, target: AxelarGovernanceService.HostStoragePath)
            }
            let hostCap = signer.getCapability<&AxelarGovernanceService.Host>(hostPrivatePath)
    
            assert(hostCap.check(), message: "Invalid Host Capability retrieved")
    assert(hostCap.borrow()!.getHostAddress()! == signer.address, message: "Host is configured for unexpected account")
            // Finally publish the Host Capability to the account that will store the Updater
            
            signer.inbox.publish(
                hostCap,
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
  