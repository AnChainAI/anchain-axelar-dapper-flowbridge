import { findFilePath } from '../../utils/testing'
import { ContractDetails, FlowConstants } from '../../utils/flow'
import { readFileSync } from 'fs'
import { join } from 'path'

export const AxelarInterchainTokenService = (
  gatewayAddress: string,
  constants: FlowConstants,
): ContractDetails => {
  return {
    name: 'InterchainTokenService',
    code: readFileSync(findFilePath(join('services', 'InterchainTokenService.cdc')), 'utf8').replace(
      '"../AxelarGateway.cdc"',
      gatewayAddress,
    )
    .replace('"FungibleToken"', constants.FLOW_FT_ADDRESS)
    .replace('"../AxelarFungibleToken.cdc"', gatewayAddress)
  }
}
