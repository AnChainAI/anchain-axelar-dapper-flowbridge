import * as fclCrypto from '@onflow/util-encode-key'
import { ec as EC } from 'elliptic'
import { SHA3 } from 'sha3'

const ec = new EC('p256')

export const hashMsg = (msg: string) => {
  const sha = new SHA3(256)
  sha.update(Buffer.from(msg, 'hex'))
  return sha.digest()
}

export const signWithKey = (privateKey: string, msg: string) => {
  const key = ec.keyFromPrivate(Buffer.from(privateKey, 'hex'))
  const sig = key.sign(hashMsg(msg))
  const n = 32
  const r = sig.r.toArrayLike(Buffer, 'be', n)
  const s = sig.s.toArrayLike(Buffer, 'be', n)
  return Buffer.concat([r, s]).toString('hex')
}

export const generateKeys = () => {
  const keys = ec.genKeyPair()
  const privateKey = keys.getPrivate('hex')
  const publicKey = keys.getPublic('hex').replace(/^04/, '')
  return {
    publicKey,
    privateKey,
  }
}

export const encodePublicKey = (publicKey: string, keyWeight = 1000) => {
  return fclCrypto.encodeKey(publicKey, 2, 3, keyWeight)
}
