import { FlowConstants } from './constants.interface'

export interface ScriptFunctionParams<T> {
  readonly constants: FlowConstants
  readonly args: T
}
