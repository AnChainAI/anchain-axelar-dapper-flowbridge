import * as cdc from '@onflow/types'

export function wrapInputParams(params: (string | string[])[][]) {
  const datas: (string | string[])[][] = []
  const types: unknown[] = []

  params.forEach((p) => {
    datas.push(p)
    if (p.length === 6) {
      types.push(
        cdc.Array([
          cdc.String,
          cdc.String,
          cdc.String,
          cdc.String,
          cdc.String,
          cdc.UInt256,
        ]),
      )
    } else if (p.length === 3) {
      types.push(
        cdc.Array([cdc.Array(cdc.String), cdc.Array(cdc.UInt256), cdc.UInt256]),
      )
    }
  })

  return { datas, types }
}
