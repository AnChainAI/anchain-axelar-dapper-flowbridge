import { findFilePath } from '../../utils/testing'
import { ContractDetails } from '../../utils/flow'
import { readFileSync } from 'fs'
import { join } from 'path'

export const AxelarAuthWeightedContract = (): ContractDetails => {
  return {
    name: 'AxelarAuthWeighted',
    code: readFileSync(
      findFilePath(join('auth', 'AxelarAuthWeighted.cdc')),
      'utf8',
    ),
  }
}
