import Crypto

pub contract AxelarAuthWeighted {
  pub var currentEpoch: UInt256
  pub let hashForEpoch: {UInt256: String}
  pub let epochForHash: {String: UInt256}

  priv let OLD_KEY_RETENTION: UInt256

  // EXTERNAL FUNCTIONALITY
  pub fun validateProof(message: String, operators: [String], weights: [UInt256], threshold: UInt256, signatures: [String]): Bool {
    let operatorsHash = self._operatorsToHash(operators: operators, weights: weights, threshold: threshold)
    let operatorsEpoch = self.epochForHash[operatorsHash]
    let epoch = self.currentEpoch

    if operatorsEpoch == nil || epoch - operatorsEpoch! >= self.OLD_KEY_RETENTION {
      panic("Invalid operators")
    }

    self._validateSignatures(message: message, operators: operators, weights: weights, threshold: threshold, signatures: signatures)

    return operatorsEpoch! == epoch
  }

  //TODO: Reiview
  access(account) fun transferOperatorship(newOperators: [String], newWeights: [UInt256], newThreshold: UInt256){
    self._transferOperatorship(newOperators: newOperators, newWeights: newWeights, newThreshold: newThreshold)
  }

  priv fun _transferOperatorship(newOperators: [String], newWeights: [UInt256], newThreshold: UInt256){
    let operatorsLength = newOperators.length
    let weightsLength = newWeights.length

    if (operatorsLength == 0 || !self._isSortedAscAndContainsNoDuplicate(operators: newOperators)){
      panic("Invalid Operators")
    }
    if (weightsLength != operatorsLength){
      panic("Invalid Weights")
    }

    var totalWeight: UInt256 = 0
    for weight in newWeights{
      totalWeight = totalWeight + weight
    }

    if(newThreshold == 0 || totalWeight < newThreshold){
      panic("Invalid Threshold")
    }
    
    let newOperatorsHash = self._operatorsToHash(operators: newOperators, weights: newWeights, threshold: newThreshold)
    if (self.epochForHash[newOperatorsHash] != 0){
      panic("Duplicate Operators")
    }

    var epoch = self.currentEpoch + 1
    self.currentEpoch = epoch
    self.hashForEpoch[epoch] = newOperatorsHash
    self.epochForHash[newOperatorsHash] = epoch
  }

  priv fun _validateSignatures(message: String, operators: [String], weights: [UInt256], threshold: UInt256, signatures: [String]) {
    let operatorsLength = operators.length
    let signaturesLength = signatures.length
    var operatorIndex = 0
    var weight: UInt256 = 0

    // looking for signers within operators
    // assuming that both operators and signatures are sorted
    for signature in signatures {
      // looping through operators to find a matching operator for current signature
      while operatorIndex < operatorsLength && self._validateEthSignature(operator: operators[operatorIndex], signature: signature, message: message) == false {
        operatorIndex = operatorIndex + 1
      }

      // check to see if all operators have been used
      if operatorIndex == operatorsLength {
        panic("Malformed Signers")
      }

      // if a an operator is found for the signature
      // add up the weight of that operator's signature
      weight = weight + weights[operatorIndex]

      // complete the validation when the weight
      // reaches or surpasses the threshold
      if weight >= threshold {
        return
      }

      // move on to the next operator after weight accumulation
      operatorIndex = operatorIndex + 1
    }

    // panic if weight is below threshold after validating all signatures
    panic("Low Signatures Weight")
  }

  //TODO: REVIEW
  priv fun _isSortedAscAndContainsNoDuplicate(operators: [String]): Bool {
    let operatorsLength = operators.length
    var prevOperator = operators[0]
    var i = 0

    while i < operatorsLength{
      if (prevOperator >= operators[i]){
        return false
      }
      prevOperator = operators[i]
    }

    return true
  }

  priv fun _validateEthSignature(operator: String, signature: String, message: String): Bool {
    let decodedHexOperatorPublicKey = operator.decodeHex()
    let decodedHexSignature = signature.decodeHex()

    // following Ethereum's \x19Ethereum Signed Message:\n<length of message><message> convention
    let ethereumMessagePrefix: String = "\u{0019}Ethereum Signed Message:\n".concat(message.length.toString())
    let fullMessage = ethereumMessagePrefix.concat(message)

    let publicKey = PublicKey(
      publicKey: decodedHexOperatorPublicKey,
      signatureAlgorithm: SignatureAlgorithm.ECDSA_secp256k1
    )

    let isValid = publicKey.verify(signature: decodedHexSignature, signedData: fullMessage.utf8, domainSeparationTag: "", hashAlgorithm: HashAlgorithm.KECCAK_256)

    return isValid
  }

  priv fun _operatorsToHash(operators: [String], weights: [UInt256], threshold: UInt256): String {
    let data: [UInt8] = []
    for operator in operators {
      data.appendAll(operator.utf8)
    }

    for weight in weights {
      data.appendAll(weight.toBigEndianBytes())
    }

    data.appendAll(threshold.toBigEndianBytes())

    return String.encodeHex(Crypto.hash(data, algorithm: HashAlgorithm.KECCAK_256))
  }

  init() {
    self.currentEpoch = 0
    self.hashForEpoch = {}
    self.epochForHash = {}
    self.OLD_KEY_RETENTION = 16
  }
}