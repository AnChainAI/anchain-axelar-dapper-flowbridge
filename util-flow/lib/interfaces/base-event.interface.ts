export interface BaseEvent<T> {
  readonly type: string
  readonly transactionId: string
  readonly transactionIndex: number
  readonly eventIndex: number
  readonly data: T
}
