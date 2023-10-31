import { HDNodeWallet } from 'ethers'
import { sortBy } from 'lodash'

export async function getWeightedSignatureProof(
  data: string,
  operators: HDNodeWallet[],
) {
  const ethSignatures = await Promise.all(
    sortBy(operators, (wallet) =>
      wallet.signingKey.publicKey.toLowerCase(),
    ).map((wallet) => wallet.signMessage(data)),
  )
  const signatures = ethSignatures.map((ethSig) => {
    const removedPrefix = ethSig.replace(/^0x/, '')
    const sigObj = {
      r: removedPrefix.slice(0, 64),
      s: removedPrefix.slice(64, 128),
    }
    return sigObj.r + sigObj.s
  })

  return signatures
}
