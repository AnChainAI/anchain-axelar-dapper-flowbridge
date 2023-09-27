import { CadenceType } from './cdc-type.interface'

export interface ScriptArgs {
  readonly cadence: string
  readonly args: (
    arg: (a: unknown, t: unknown) => unknown,
    t: CadenceType
  ) => unknown[]
}
