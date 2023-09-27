import { KeyValue } from '../interfaces/key-value.interface'
import { parseObject } from './object.wrapper'
import * as t from '@onflow/types'

export function parseObjects(
  objs: Record<string, string | null>[]
): [KeyValue<string | unknown>[][], unknown] {
  const flowMetas: KeyValue<string | unknown>[][] = []
  const typeMetas: unknown[] = []
  for (const obj of objs) {
    const [flowMeta, typeMeta] = parseObject(obj)
    flowMetas.push(flowMeta)
    typeMetas.push(typeMeta)
  }
  return [flowMetas, t.Array(typeMetas)]
}

export function wrapObjects(objs: Record<string, string | null>[]) {
  const [flowMeta, typeMeta] = parseObjects(objs)
  return { flowMeta, typeMeta }
}
