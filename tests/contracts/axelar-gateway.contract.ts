import { findFilePath } from '../../utils/testing'
import { ContractDetails } from '../../utils/flow'
import { readFileSync } from 'fs'

export const AxelarGatewayContract = (
  adminAddress: string,
  utilsAddress: string,
): ContractDetails => {
  return {
    name: 'AxelarGateway',
    code: readFileSync(findFilePath('AxelarGateway.cdc'), 'utf8')
      .replace('"./auth/AxelarAuthWeighted.cdc"', adminAddress)
      .replace('"./standard/AddressUtils.cdc"', utilsAddress),
  }
}
