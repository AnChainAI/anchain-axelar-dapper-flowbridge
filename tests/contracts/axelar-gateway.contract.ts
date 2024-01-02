import { findFilePath } from '../../utils/testing'
import { ContractDetails, FlowConstants } from '../../utils/flow'
import { readFileSync } from 'fs'

export const AxelarGatewayContract = (
  adminAddress: string,
  utilsAddress: string,
  constants: FlowConstants,
): ContractDetails => {
  return {
    name: 'AxelarGateway',
    code: readFileSync(findFilePath('AxelarGateway.cdc'), 'utf8')
      .replace('"./auth/AxelarAuthWeighted.cdc"', adminAddress)
      .replace('"./standard/AddressUtils.cdc"', utilsAddress)
      .replace('"FungibleToken"', constants.FLOW_FT_ADDRESS),
  }
}
