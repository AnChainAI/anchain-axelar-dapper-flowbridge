import { TransactionStatusString } from '../enums/transaction-status-string.enum'
import { BaseEvent } from './base-event.interface'

/**
 * https://grpc.github.io/grpc/core/md_doc_statuscodes.html
 * https://docs.onflow.org/fcl/reference/api/#transaction-statuses
 * https://docs.onflow.org/fcl/reference/api/#gettransaction
 */
export interface TransactionStatus {
  readonly blockId: string
  readonly status: 0 | 1 | 2 | 3 | 4 | 5
  readonly statusString: TransactionStatusString
  readonly statusCode: number
  readonly errorMessage: string
  readonly events: BaseEvent<unknown>[]
}
