import {
  TransactionFunctionParams,
  sendTransaction,
  FlowConstants,
} from '../../utils/flow'

const CODE = (constants: FlowConstants) => `
import AxelarGateway from ${constants.FLOW_ADMIN_ADDRESS}

transaction(destinationChain: String, destinationContractAddress: String, payload: [UInt8]) {
  let senderIdentityCap: Capability<&{AxelarGateway.SenderIdentity}>
  prepare(acct: AuthAccount) {
    if !acct.getCapability<&{AxelarGateway.SenderIdentity}>(/private/AxelarSenderIdentity).check() {
      acct.unlink(/private/AxelarSenderIdentity)
      self.senderIdentityCap = acct.link<&{AxelarGateway.SenderIdentity}>(/private/AxelarSenderIdentity, target: /storage/AxelarExecutable) ?? panic("Could not create Axelar Sender Identity capability")
    } else {
      self.senderIdentityCap = acct.getCapability<&{AxelarGateway.SenderIdentity}>( /private/AxelarSenderIdentity)
    }
  }

  execute {
    AxelarGateway.callContract(senderIdentity: self.senderIdentityCap, destinationChain: destinationChain, destinationContractAddress: destinationContractAddress, payload: payload)
  }
}
`

export interface CallContractArgs {
  readonly destinationChain: string
  readonly destinationContractAddress: string
  readonly payload: number[]
}

export async function callContract(
  params: TransactionFunctionParams<CallContractArgs>,
) {
  return await sendTransaction({
    cadence: CODE(params.constants),
    args: (arg, t) => [
      arg(params.args.destinationChain, t.String),
      arg(params.args.destinationContractAddress, t.String),
      arg(
        params.args.payload.map((n) => n.toString()),
        t.Array(t.UInt8),
      ),
    ],
    authorizations: [params.authz],
    payer: params.authz,
    proposer: params.authz,
    limit: 9999,
  })
}
