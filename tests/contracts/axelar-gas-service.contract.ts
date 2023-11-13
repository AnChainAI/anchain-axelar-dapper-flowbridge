import { findFilePath } from '../../utils/testing'
import { ContractDetails } from '../../utils/flow'
import { readFileSync } from 'fs'
import { join } from 'path'

export const AxelarGasServiceContract = (): ContractDetails => {
  return {
    name: 'AxelarGasService',
    code: readFileSync(
      findFilePath(join('services', 'AxelarGasService.cdc')),
      'utf8',
    ),
  }
}
