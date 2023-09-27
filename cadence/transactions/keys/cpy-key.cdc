transaction(index: Int, copies: UInt64) {
  prepare(signer: AuthAccount) {
    if let key = signer.keys.get(keyIndex: index) {
      var i: UInt64 = 0
      while i < copies {
        signer.keys.add(
          publicKey: key.publicKey,
          hashAlgorithm: key.hashAlgorithm,
          weight: 0.0
        )
        i = i + 1
      }
    } else {
      panic("No key was found at index ".concat(index.toString()))
    }
  }
}