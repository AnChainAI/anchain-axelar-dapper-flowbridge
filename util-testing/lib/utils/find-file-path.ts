import { existsSync, readdirSync } from 'fs'
import { basename, resolve } from 'path'

const cache = new Map<string, string>()

const neighbors = (node: string) => {
  const nbrs = [resolve(node, '..')]
  for (const f of readdirSync(node, { withFileTypes: true })) {
    if (f.isDirectory()) {
      nbrs.push(resolve(node, f.name))
    }
  }
  return nbrs
}

export function findFilePath(
  filename: string,
  exclude: string[] = ['node_modules']
) {
  const p = cache.get(filename)
  if (!p) {
    const blacklst = new Set<string>(exclude)
    const startDir = resolve(__dirname)
    const explored = new Set<string>()
    const frontier: string[] = []
    explored.add(startDir)
    frontier.push(startDir)
    while (frontier.length > 0) {
      const node = frontier.shift()!
      const path = resolve(node, filename)
      if (existsSync(path)) {
        cache.set(filename, path)
        return path
      }
      for (const n of neighbors(node)) {
        if (!explored.has(n) && !blacklst.has(basename(n))) {
          explored.add(n)
          frontier.push(n)
        }
      }
    }
    throw new Error(`${filename} was not found.`)
  } else {
    return p
  }
}
