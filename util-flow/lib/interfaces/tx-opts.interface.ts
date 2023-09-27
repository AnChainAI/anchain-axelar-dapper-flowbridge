export interface TransactionOpts {
  readonly payer: () => unknown
  readonly proposer: () => unknown
  readonly authorizations: { (): unknown }[]
  readonly limit: number
}
