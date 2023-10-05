import { findFilePath } from '../../utils/testing'
import { ContractDetails } from '../../utils/flow'
import { readFileSync } from 'fs'

export const AxelarGatewayContract = (
  adminAddress: string,
): ContractDetails => {
  return {
    name: 'AxelarGateway',
    code: readFileSync(findFilePath('AxelarGateway.cdc'), 'utf8')
      .replace('"./interfaces/IAxelarExecutable.cdc"', adminAddress)
      .replace('"./auth/AxelarAuthWeighted.cdc"', adminAddress)
      .replace('"./util/EternalStorage.cdc"', adminAddress),
  }
}
