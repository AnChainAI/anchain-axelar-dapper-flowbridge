import { KeyValue } from '../interfaces/key-value.interface'
import * as t from '@onflow/types'

export function parseObject(
  obj: Record<string, string | null>
): [KeyValue<string | unknown>[], unknown] {
  const flowMeta: KeyValue<string | unknown>[] = []
  const typeMeta: KeyValue<string | unknown>[] = []
  for (const prop in obj) {
    const val = obj[prop] ?? ''
    flowMeta.push({ key: prop, value: val.toString() })
    typeMeta.push({ key: t.String, value: t.String })
  }
  return [flowMeta, t.Dictionary(typeMeta)]
}

export function wrapObject(obj: Record<string, string | null>) {
  const [flowMeta, typeMeta] = parseObject(obj)
  return { flowMeta, typeMeta }
}
