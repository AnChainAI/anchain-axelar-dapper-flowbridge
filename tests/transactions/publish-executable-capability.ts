import {
  TransactionFunctionParams,
  sendTransaction,
  FlowConstants,
} from '../../utils/flow'

const CODE = (constants: FlowConstants) => `
import AxelarGateway from ${constants.FLOW_ADMIN_ADDRESS}

transaction(recipient: Address) {
  prepare(acct: AuthAccount) {
    if !acct.getCapability<&{AxelarGateway.Executable}>(/private/AxelarExecutable).check() {
      let axelarExecutableCap = acct.link<&{AxelarGateway.Executable}>(/private/AxelarExecutable, target: /storage/AxelarExecutable)
      if (axelarExecutableCap != nil) {
        acct.inbox.publish(axelarExecutableCap!, name: AxelarGateway.PREFIX_APP_CAPABILITY_NAME.concat(acct.address.toString()), recipient: recipient)
      } else {
        panic("Could not create Axelar Executable capability")
      }
    } else {
      panic("Axelar Executable capability already exists")
    }
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
