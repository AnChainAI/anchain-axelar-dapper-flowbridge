import { ScriptFunctionParams } from './script-func-params.interface'

export interface TransactionFunctionParams<T> extends ScriptFunctionParams<T> {
  readonly authz: unknown
}
