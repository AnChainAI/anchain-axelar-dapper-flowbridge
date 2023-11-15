import { findFilePath } from '../../utils/testing'
import { ContractDetails } from '../../utils/flow'
import { readFileSync } from 'fs'
import { join } from 'path'

export const AxelarGovernanceServiceContract = (
  gatewayAddress: string,
): ContractDetails => {
  return {
    name: 'AxelarGovernanceService',
    code: readFileSync(findFilePath(join('services', 'AxelarGovernanceService.cdc')), 'utf8').replace(
      '"../AxelarGateway.cdc"',
      gatewayAddress,
    ),
  }
}
