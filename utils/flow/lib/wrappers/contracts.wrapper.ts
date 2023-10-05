import { ContractDetails } from '../interfaces/contract-details.interface'
import { KeyValue } from '../interfaces/key-value.interface'
import * as cdc from '@onflow/types'

export function wrapContracts(contracts: ContractDetails[]) {
  const datas: KeyValue<string | unknown>[][] = []
  const types: KeyValue<string | unknown>[] = []
  for (const c of contracts) {
    datas.push([
      { key: 'name', value: c.name },
      { key: 'code', value: Buffer.from(c.code).toString('hex') },
    ])
    types.push(
      cdc.Dictionary([
        { key: cdc.String, value: cdc.String },
        { key: cdc.String, value: cdc.String },
      ]),
    )
  }
  return { datas, types }
}
