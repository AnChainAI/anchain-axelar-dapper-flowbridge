import { findFilePath } from '../../utils/testing'
import { ContractDetails } from '../../utils/flow'
import { readFileSync } from 'fs'

export const ExampleApplicationContract = (
  gatewayAddress: string,
): ContractDetails => {
  return {
    name: 'ExampleApplication',
    code: readFileSync(findFilePath('ExampleApplication.cdc'), 'utf8').replace(
      '"../AxelarGateway.cdc"',
      gatewayAddress,
    ),
  }
}
