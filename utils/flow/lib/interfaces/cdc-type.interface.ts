export interface CadenceType {
  readonly Address: unknown
  readonly UInt256: unknown
  readonly UFix64: unknown
  readonly UInt64: unknown
  readonly UInt8: unknown
  readonly String: unknown
  readonly Bool: unknown
  readonly Int: unknown
  readonly Optional: (arg: unknown) => unknown
  readonly Dictionary: (arr: unknown) => unknown
  readonly Array: (arr: unknown) => unknown
}
