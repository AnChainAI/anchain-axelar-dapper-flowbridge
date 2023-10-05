import { findFilePath } from '../../utils/testing'
import { ContractDetails } from '../../utils/flow'
import { readFileSync } from 'fs'
import { join } from 'path'

export const IAxelarExecutableContract = (): ContractDetails => {
  return {
    name: 'IAxelarExecutable',
    code: readFileSync(
      findFilePath(join('interfaces', 'IAxelarExecutable.cdc')),
      'utf8',
    ),
  }
}
