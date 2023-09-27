export interface MultiSigParams {
  readonly signatures: string[]
  readonly addresses: string[]
  readonly keyIndexes: number[]
  readonly nonce: number
}
