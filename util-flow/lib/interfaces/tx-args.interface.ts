import { TransactionOpts } from './tx-opts.interface'
import { ScriptArgs } from './script-args.interface'

export interface TransactionArgs extends ScriptArgs, TransactionOpts {}
