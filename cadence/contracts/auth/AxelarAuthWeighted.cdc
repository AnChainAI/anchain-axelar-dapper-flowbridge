import Crypto

access(all) contract AxelarAuthWeighted {
  access(all) var currentEpoch: UInt256
  access(all) let hashForEpoch: {UInt256: String}
  access(all) let epochForHash: {String: UInt256}

  access(self) let OLD_KEY_RETENTION: UInt256

  access(all) event OperatorshipTransferred(
    newOperators: [String],
    newWeights: [UInt256],
    newThreshold: UInt256
  )

  access(all) struct ValidationStatus {
    access(all) let isValid: Bool
    access(all) let errorMessage: String? /*	An error message with 20 characters in length if it exists */

    init(isValid: Bool, errorMessage: String?) {
      pre {
        errorMessage == nil || errorMessage!.length <= 20 : "Error message length must be less than or equal to 20"
      }

      self.isValid = isValid
      self.errorMessage = errorMessage
    }
  }

  access(all) struct TransferStatus {
    access(all) let isTransferred: Bool
    access(all) let errorMessage: String? /*	An error message with 20 characters in length if it exists */

    init(isTransferred: Bool, errorMessage: String?) {
      pre {
        errorMessage == nil || errorMessage!.length <= 20 : "Error message length must be less than or equal to 20"
      }

      self.isTransferred = isTransferred
      self.errorMessage = errorMessage
    }
  }

  access(all) struct TransferOperatorshipParams {
    access(all) let newOperators: [String]
    access(all) let newWeights: [UInt256]
    access(all) let newThreshold: UInt256

    init(newOperators: [String], newWeights: [UInt256], newThreshold: UInt256) {
        self.newOperators = newOperators
        self.newThreshold = newThreshold
        self.newWeights = newWeights
    }
  }

  /**************************\
  |* External Functionality *|
  \**************************/
  access(all) fun validateProof(message: String, operators: [String], weights: [UInt256], threshold: UInt256, signatures: [String]): ValidationStatus {
    let operatorsHash = self._operatorsToHash(operators: operators, weights: weights, threshold: threshold)
    let operatorsEpoch = self.epochForHash[operatorsHash]
    let epoch = self.currentEpoch

    // panic and revert transaction when signing operators are invalid
    if operatorsEpoch == nil || epoch - operatorsEpoch! >= self.OLD_KEY_RETENTION {
      panic("Invalid Operators")
    }

    let isValidSig = self._validateSignatures(message: message, operators: operators, weights: weights, threshold: threshold, signatures: signatures)

    return ValidationStatus(
      isValid: operatorsEpoch! == epoch,
      errorMessage: nil
    )
  }

  /***********************\
  |* Owner Functionality *|
  \***********************/
  access(account) fun transferOperatorship(
    message: String,
    operators: [String],
    weights: [UInt256],
    threshold: UInt256,
    signatures: [String],
    params: TransferOperatorshipParams): TransferStatus {
      let validatedProof = self.validateProof(message: message, operators: operators, weights: weights, threshold: threshold, signatures: signatures)
      if !validatedProof.isValid {
        return TransferStatus(
          isTransferred: false,
          errorMessage: validatedProof.errorMessage
        )
      }

      return self._transferOperatorship(newOperators: params.newOperators, newWeights: params.newWeights, newThreshold: params.newThreshold)
  }

  /**************************\
  |* Internal Functionality *|
  \**************************/
  access(self) fun _transferOperatorship(newOperators: [String], newWeights: [UInt256], newThreshold: UInt256): TransferStatus {
    let operatorsLength = newOperators.length
    let weightsLength = newWeights.length

    if (operatorsLength == 0) {
      return TransferStatus(
        isTransferred: false,
        errorMessage: "Invalid Operators"
      )
    }
    if (!self._isSortedAscAndContainsNoDuplicate(operators: newOperators)) {
      return TransferStatus(
        isTransferred: false,
        errorMessage: "Unsorted Operators"
      )
    }
    if (weightsLength != operatorsLength) {
      return TransferStatus(
        isTransferred: false,
        errorMessage: "Invalid Weights"
      )
    }

    var totalWeight: UInt256 = 0
    for weight in newWeights {
      totalWeight = totalWeight + weight
    }

    if (newThreshold == 0 || totalWeight < newThreshold) {
      return TransferStatus(
        isTransferred: false,
        errorMessage: "Invalid Threshold"
      )
    }
    
    let newOperatorsHash = self._operatorsToHash(operators: newOperators, weights: newWeights, threshold: newThreshold)
    if (self.epochForHash[newOperatorsHash] != nil) {
      return TransferStatus(
        isTransferred: false,
        errorMessage: "Duplicate Operators"
      )
    }

    var epoch = self.currentEpoch + 1
    self.currentEpoch = epoch
    self.hashForEpoch[epoch] = newOperatorsHash
    self.epochForHash[newOperatorsHash] = epoch

    emit OperatorshipTransferred(newOperators: newOperators, newWeights: newWeights, newThreshold: newThreshold)
    return TransferStatus(
      isTransferred: true,
      errorMessage: nil
    )
  }

  access(self) fun _validateSignatures(message: String, operators: [String], weights: [UInt256], threshold: UInt256, signatures: [String]): ValidationStatus {
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
        return ValidationStatus(
          isValid: false,
          errorMessage: "Malformed Signers"
        )
      }

      // if a an operator is found for the signature
      // add up the weight of that operator's signature
      weight = weight + weights[operatorIndex]

      // complete the validation when the weight
      // reaches or surpasses the threshold
      if weight >= threshold {
        return ValidationStatus(
          isValid: true,
          errorMessage: nil
        )
      }

      // move on to the next operator after weight accumulation
      operatorIndex = operatorIndex + 1
    }

    // fail if weight is below threshold after validating all signatures
    return ValidationStatus(
      isValid: false,
      errorMessage: "Low Sigs Weight"
    )
  }

  access(self) fun _isSortedAscAndContainsNoDuplicate(operators: [String]): Bool {
    let operatorsLength = operators.length
    var prevOperator = operators[0]
    var i = 1

    while i < operatorsLength {
      if (prevOperator >= operators[i]) {
        return false
      }
      prevOperator = operators[i]
      i = i + 1
    }

    return true
  }

  access(self) fun _validateEthSignature(operator: String, signature: String, message: String): Bool {
    let decodedHexPublicKey = operator.decodeHex()
    let decodedHexSignature = signature.decodeHex()

    // following Ethereum's \x19Ethereum Signed Message:\n<length of message><message> convention
    let ethereumMessagePrefix: String = "\u{0019}Ethereum Signed Message:\n".concat(message.length.toString())
    let fullMessage: String = ethereumMessagePrefix.concat(message)

    let key = PublicKey(
      publicKey: operator.decodeHex(),
      signatureAlgorithm: SignatureAlgorithm.ECDSA_secp256k1
    )

    let isValid = key.verify(signature: decodedHexSignature, signedData: fullMessage.utf8, domainSeparationTag: "", hashAlgorithm: HashAlgorithm.KECCAK_256)
    
    return isValid
  }

  access(self) fun _operatorsToHash(operators: [String], weights: [UInt256], threshold: UInt256): String {
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

  init(
    recentOperatorsSet:[[String]],
    recentWeightsSet: [[UInt256]],
    recentThresholdSet: [UInt256]
  ) {
    self.currentEpoch = 0
    self.hashForEpoch = {}
    self.epochForHash = {}
    self.OLD_KEY_RETENTION = 16

    var i = 0
    while i < recentOperatorsSet.length {
      self._transferOperatorship(
        newOperators: recentOperatorsSet[i],
        newWeights: recentWeightsSet[i],
        newThreshold: recentThresholdSet[i]
      )
      i = i + 1
    }
  }
}
