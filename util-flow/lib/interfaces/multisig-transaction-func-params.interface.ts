import { TransactionFunctionParams } from './transaction-func-params.interface'
import { MultiSigParams } from './multi-sig-params.interface'

export interface MultiSigTransactionFunctionParams<T>
  extends TransactionFunctionParams<T> {
  readonly multisigParams: MultiSigParams
}
