import { findFilePath } from '../../utils/testing'
import { ContractDetails, FlowConstants } from '../../utils/flow'
import { readFileSync } from 'fs'
import { join } from 'path'

export const AxelarGovernanceServiceContract = (
  gatewayAddress: string,
  constants: FlowConstants,
): ContractDetails => {
  return {
    name: 'AxelarGovernanceService',
    code: readFileSync(findFilePath(join('services', 'AxelarGovernanceService.cdc')), 'utf8').replace(
      '"../AxelarGateway.cdc"',
      gatewayAddress,
    )
    .replace('"FungibleToken"', constants.FLOW_FT_ADDRESS)
  }
}
