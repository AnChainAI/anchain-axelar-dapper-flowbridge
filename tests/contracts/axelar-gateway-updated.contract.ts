import { findFilePath } from '../../utils/testing'
import { ContractDetails } from '../../utils/flow'
import { readFileSync } from 'fs'
import { join } from 'path'

export const AxelarGatewayUpdateContract = (
  adminAddress: string,
  utilsAddress: string,
): ContractDetails => {
  return {
    name: 'AxelarGateway',
    code: readFileSync(findFilePath(join('tests','utils','updated-contracts', 'AxelarGateway-update.cdc')), 'utf8')
      .replace('"./auth/AxelarAuthWeighted.cdc"', adminAddress)
      .replace('"./standard/AddressUtils.cdc"', utilsAddress),
  }
}
