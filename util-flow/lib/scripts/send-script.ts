import { ScriptArgs } from '../interfaces/script-args.interface'
import * as fcl from '@onflow/fcl'

export async function sendScript<T>(args: ScriptArgs): Promise<T> {
  return await fcl.query(args)
}
