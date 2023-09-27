import { TransactionStatus } from '../interfaces/tx-status.interface'
import { TransactionArgs } from '../interfaces/tx-args.interface'
import * as fcl from '@onflow/fcl'

export async function sendTransaction(args: TransactionArgs) {
  const txId: string = await fcl.mutate(args)
  return (await fcl.tx(txId).onceSealed()) as TransactionStatus
}
