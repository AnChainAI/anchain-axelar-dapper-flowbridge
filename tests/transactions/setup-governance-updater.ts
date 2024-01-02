import {
    TransactionFunctionParams,
    sendTransaction,
    FlowConstants,
  } from '../../utils/flow'
  
  const CODE = (address: string) => `
  import AxelarGovernanceService from ${address}

    transaction(blockUpdateBoundary: UInt64, contractName: String, code: String) {
        prepare(signer: AuthAccount) {
            if !signer.getCapability<&AuthAccount>(AxelarGovernanceService.UpdaterContractAccountPrivatePath).check() {
                signer.unlink(AxelarGovernanceService.UpdaterContractAccountPrivatePath)
                signer.linkAccount(AxelarGovernanceService.UpdaterContractAccountPrivatePath)
            }
            let accountCap: Capability<&AuthAccount> = signer.getCapability<&AuthAccount>(AxelarGovernanceService.UpdaterContractAccountPrivatePath)
            if signer.type(at: AxelarGovernanceService.UpdaterStoragePath) != nil {
                panic("Updater already configured at expected path!")
            }
            signer.save(
                <- AxelarGovernanceService.createNewUpdater(
                    blockUpdateBoundary: blockUpdateBoundary,
                    accounts: [accountCap],
                    deployments: [[
                        AxelarGovernanceService.ContractUpdate(
                            address: signer.address,
                            name: contractName,
                            code: code
                        )
                    ]]
                ),
                to: AxelarGovernanceService.UpdaterStoragePath
            )
            signer.unlink(AxelarGovernanceService.UpdaterPublicPath)
            signer.unlink(AxelarGovernanceService.DelegatedUpdaterPrivatePath)
            signer.link<&AxelarGovernanceService.Updater{AxelarGovernanceService.UpdaterPublic}>(AxelarGovernanceService.UpdaterPublicPath, target: AxelarGovernanceService.UpdaterStoragePath)
            signer.link<&AxelarGovernanceService.Updater{AxelarGovernanceService.DelegatedUpdater, AxelarGovernanceService.UpdaterPublic}>(AxelarGovernanceService.DelegatedUpdaterPrivatePath, target: AxelarGovernanceService.UpdaterStoragePath)
        }
    }
  `
  
  export interface PublishCapabilityArgs {
    readonly recipient: string
  }
  
  export async function publishExecutableCapability(
    params: TransactionFunctionParams<PublishCapabilityArgs>,
  ) {
    return await sendTransaction({
      cadence: CODE(params.constants),
      args: (arg, t) => [arg(params.args.recipient, t.Address)],
      authorizations: [params.authz],
      payer: params.authz,
      proposer: params.authz,
      limit: 9999,
    })
  }
  