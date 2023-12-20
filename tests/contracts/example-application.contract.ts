import { findFilePath } from '../../utils/testing'
import { ContractDetails, FlowConstants } from '../../utils/flow'
import { readFileSync } from 'fs'

export const ExampleApplicationContract = (
  gatewayAddress: string,
  constants: FlowConstants,
): ContractDetails => {
  return {
    name: 'ExampleApplication',
    code: readFileSync(findFilePath('ExampleApplication.cdc'), 'utf8').replace(
      '"../AxelarGateway.cdc"',
      gatewayAddress,
    )
    .replace('"FungibleToken"', constants.FLOW_FT_ADDRESS),
  }
}
