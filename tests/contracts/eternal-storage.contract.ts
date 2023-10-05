import { findFilePath } from '../../utils/testing'
import { ContractDetails } from '../../utils/flow'
import { readFileSync } from 'fs'
import { join } from 'path'

export const EternalStorageContract = (
  adminAddress: string,
): ContractDetails => {
  return {
    name: 'EternalStorage',
    code: readFileSync(
      findFilePath(join('util', 'EternalStorage.cdc')),
      'utf8',
    ).replace('"../interfaces/IAxelarExecutable.cdc"', adminAddress),
  }
}
