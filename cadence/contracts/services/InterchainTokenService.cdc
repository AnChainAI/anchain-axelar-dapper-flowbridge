import AxelarGateway from "../AxelarGateway";
import FungibleToken from "flow-ft";
import Crypto

access(all) contract InterchainTokenService{

    access(all) enum TokenManagerType {
        case Native
        case Managed
    }

    access(all)  let prefixNativeTokenName: String
    access(all)  let prefixAuthCapabilityName: String
    access(all)  let prefixVaultName: String
    access(all)  let prefixManagedTokenName: String
    access(all)  let inboxAccountCapabilityNamePrefix: String
    access(all)  let tokenPublicKey: String
    access(all)  let accountCreationFee: UFix64

    // access(self) let approvedCommands: @{String: ApprovedCommands} 
    access(self) let approvedWithdrawls: [[UInt8]]
    access(self) let tokens: @{Address: TokenManagerType}

    access(all) let INIT_INTERCHAIN_TRANSFER: [UInt8]

    // access(all) resource ApprovedCommands {
    //     access(all) var destinationAddress: Address
    //     access(all) var action: String
    //     access(all) var sourceChain: String
    //     access(all) var soruceAddress: String
    //     access(all) var payload: [UInt8]


    //     init(destinationAddress: Address, action: String, sourceChain: String, sourceAddress: String, payload: [UInt8]){
    //         self.destinationAddress = destinationAddress
    //         self.action = action
    //         self.sourceChain = sourceChain
    //         self.soruceAddress = sourceAddress
    //         self.payload = payload
    //     }
    // }

    access(all) resource NativeTokens{
        access(all) let contractAddress: Address
        access(all) let contractName: String
        access(account) let vaultRef: &FungibleToken.Vault

        init(
            contractName: String,
            contractAddress: Address,
            vaultRef: &FungibleToken.Vault,
        ) {
            self.contractAddress = contractAddress
            self.contractName = contractName
            self.vaultRef = vaultRef
        }
    }

    access(all) resource ManagedTokens{
        access(all) let contractAddress: Address
        access(all) let contractName: String
        access(self) let authAccountCapability: Capability<&AuthAccount>
        access(self) let adminCapability: Capability<&{FungibleToken.Administrator}>
        access(account) let minterCapability: Capability<&{FungibleToken.Minter}>
        access(account) let burnerCapability: Capability<&{FungibleToken.Burner}>

        init(
            contractName: String,
            authAccountCapability: Capability<&AuthAccount>,
        ) {
            // Validate given Capability
            if !authAccountCapability.check() {
                panic("Account capability is invalid for account: ".concat(authAccountCapability.address.toString()))
            }
            self.contractAddress = authAccountCapability.borrow()!.address
            self.contractName = contractName
            self.authAccountCapability = authAccountCapability

            let contract = authAccountCapability.contracts.get(name: contractName)
            adminCap = contract.getAdminCapability()

            self.adminCapability = adminCap
            self.minterCapability <- adminCap.createNewMinter()
            self.burnerCapability <- adminCap.createNewBurner()
        }
    }

    access(all) event WithdrawlApproved(
        approvalHash: [UInt8],
        tokenAddress: Address,
        tokenName: String,
        amount: UFix64,
        destinationAddress: Address,
    )

    access(all) event TokenContractLaunched(
        contractName: String,
        contractAddress: Address,
        tokenName: String,
        tokenSymbol: String,
    )

    access(all) event InterchainTransfer(
        tokenAddress: Address,
        tokenName: String,
        sourceAddress: Address,
        destinationChain: String,
        amount: UFix64,
        datahash: [UInt8]
    )

    access(all) event InterchainTransferReceived(
        commandId: String,
        tokenId: String,
        sourceChain: String,
        sourceAddress: String,
        destinationAddress: Address,
        amount: UFix64,
        datahash: String
    )

    access(all) event TokenManagerDeploymentStarted(
        tokenId: String,
        destinationChain: String,
        //TokenManagerType??
        params: String,
    )

    init(publicKey: String, accountCreationFee: UFix64){
        self.accountCreationFee = accountCreationFee
        self.tokenPublicKey = publicKey
        self.approvedCommands <- {}
        self.tokenActions <- {}
        self.prefixAuthCapabilityName = "TokenAuthCapability_"
        self.prefixNativeTokenName = "NativeToken_"
        self.prefixManagedTokenName = "ManagedToken_"
        self.prefixVaultName = "Vault_"
    }

    access(self) fun changeAccountCreationFee(newFee: UFix64){
        self.accountCreationFee = newFee
    }

   access(all) fun interchainTransfer(contractName: String, contractAddress: Address, destinationChain: String, destinationAddress: String, vault: @FungibleToken.Vault, metadata: [UInt8]){
        let tokenHash = self.createTokenHash(contractName: contractName, address: contractAddress)
        let amount = vault.balance

   }

   access(self) fun withdraw(amount: UFix64, tokenAddress: Address, tokenName: String, reciever: &{FungibleToken.Receiver}){
        pre {
            amount > 0.0: "Amount must be greater than zero"
            if(!self.tokens.contains(tokenAddress)){
                panic("Token not onboarded")
            }
        }
        let approvalHash = self.createApprovedWithdrawlHash(reciever.address, amount, tokenAddress, tokenName)
        if !self.approvedWithdrawls.contains(approvalHash){
            panic("Withdrawl not approved")
        }
        if (self.tokens[tokenAddress] == TokenManagerType.Native){
            let nativeToken = self.account.borrow<&Capability<&NativeTokens>>(from: self.getNativeTokenPath(tokenAddress))!
            if !nativeToken.check() {
                panic("Token capability is invalid for token: ".concat(tokenAddress.toString()))
            }
            let vault = nativeToken.vaultRef
            let tempVault = vault.withdraw(amount: amount)
            reciever.deposit(from: <-tempVault)
        } else {
            let tokenManager = self.account.getCapability(self.getManagedTokenPath(tokenAddress))!.borrow<&ManagedTokens>()!
            tokenManager.burn(amount: amount)
        }
   }

   access(self) fun _transmitInterchainTransfer(contractName: String, contractAddress: Address, destinationChain: String, destinationAddress: String, metadataVersion: UInt32, metadata: [UInt8], amount: UFix64){
        if (metadataVersion > LATEST_METADATA_VERSION) {
            panic("Invalid Metadata Version")
        }

        let datahash = Crypto.hash(metadata, algorithm: HashAlgorithm.SHA3_256)

        emit InterchainTransfer(
            tokenAddress: contractAddress,
            tokenName: contractName,
            sourceAddress: self.account.address,
            destinationChain: destinationChain,
            amount: amount,
            datahash: datahash
        )

        //"call contract" here with gateway contract
    }

   }

   access(all) resource ExecutableResource: AxelarGateway.Executable, AxelarGateway.SenderIdentity {
        access(all) fun executeApp(commandResource: &AxelarGateway.CGPCommand, sourceChain: String, sourceAddress: String, payload: [UInt8], vault: FungibleToken.Vault, receiver: FungibleToken.Receiver): AxelarGateway.ExecutionStatus{
            //parse payload

            //Awaiting abi.encode/decode
            //let messageType = abi.decode(payload, (Uint256))
            


            return AxelarGateway.ExecutionStatus(
                isExecuted: true,
                statusCode: 0,
                errorMessage: ""
            )
        }
    }

    access(self) fun _processCommand(commandSelector: [UInt8], payload: [UInt8]){
        //call function based on commandSelector
    }

    access(self) fun _approveTokenWithdrawl(depositAddress: address, amount: UFix64, tokenAddress: Address, tokenName: String){
        let approvalHash = self.createApprovedWithdrawlHash(depositAddress, amount, tokenAddress, tokenName)
        self.approvedWithdrawls.append(approvalHash)
        emit WithdrawlApproved(
            approvalHash: approvalHash,
            tokenAddress: tokenAddress,
            tokenName: tokenName,
            amount: amount,
            destinationAddress: depositAddress,
        )
    }

    access(self) fun _launchToken(name: String, symbol: String){
        self.account.getCapability(/public/flowTokenReceiver).borrow<&{FungibleToken.Receiver}>()!.deposit(from: <-accountCreationFee)
        let tokenAccount = AuthAccount(payer: self.account)
        let tokenAccountAddress = tokenAccount.address
        tokenAccount.keys.add(
            PublicKey(
                publicKey: self.tokenPublicKey.decodeHex(),
                signAlgo: SignatureAlgorithm.ECDSA_P256,
                hashAlgo: HashAlgorithm.SHA3_256
            )
        )
        let tokenTemplateContract = self.account.contracts.get(name: "AxelarFungibleToken")
        tokenAccount.contracts.add(
            name: "AxelarFungibleToken",
            code: tokenTemplateContract.code,
            tokenName: name,
            tokenSymbol: symbol,
        )
        emit TokenContractLaunched(
            contractName: "AxelarFungibleToken",
            contractAddress: tokenAccountAddress,
            tokenName: name,
            tokenSymbol: symbol,
        )
        let tokenActions <- create TokenActions(contractName: "AxelarFungibleToken", authAccountCapability: tokenAccount)
        self.account.save(<-tokenActions, to: self.getManagedTokenPath(tokenAccountAddress)!)
        self.tokens[tokenAccountAddress] = TokenManagerType.Managed

        return tokenAddress
    }

    access(self) fun _onboardNativeFungibleToken(address: Address, contractName: String){
        let tokenAccount = getAccount(address)
        self.account.save( <- tokenAccount.contracts.get(name: contractName).createEmptyVault(), to: self.getVaultPath(address)!) ?? panic("Could not create vault")
        self.account.save(<- create NativeTokens(contractName: contractName, contractAddress: address, vaultRef: self.account.borrow<&FungibleToken.Vault>(from: getVaultPath(address))), to: self.getNativeTokenPath(address)!)
        self.tokens[address] = TokenManagerType.Native
    }

    access(all) fun getNativeTokenPath(_ address: Address): StoragePath? {
        return StoragePath(identifier: self.prefixNativeTokenName.concat(address.toString()))
    }

    access(all) fun getManagedTokenPath(_ address: Address): StoragePath? {
        return StoragePath(identifier: self.prefixManagedTokenName.concat(address.toString()))
    }

    access(all) fun getVaultPath(_ address: Address): StoragePath? {
        return StoragePath(identifier: self.prefixVaultName.concat(address.toString()))
    }

    access(all) fun getAuthCapabilityStoragePath(_ address: Address): StoragePath? {
        return StoragePath(identifier: self.prefixAuthCapabilityName.concat(address.toString()))
    }

    access(all) fun createTokenHash(contractName: String, address: Address): [UInt8]{
        return Crypto.hash(self.convertInputsToUtf8([contractName, address]) , algorithm: HashAlgorithm.KECCAK_256)
    }

    access(all) fun createApprovedWithdrawlHash(withdrawlAddress: Address, amount: UFix64, tokenAddress: Address, tokenName: String): [UInt8]{
        return Crypto.hash(self.convertInputsToUtf8([withdrawlAddress, amount, tokenAddress, tokenName]) , algorithm: HashAlgorithm.KECCAK_256)
    }

    access(self) fun convertInputsToUtf8(_ inputs: [AnyStruct]): [UInt8] {
        let convertedInput: [UInt8] = []

        for input in inputs {
            if input.isInstance(Type<String>()) {
                let stringInput = input as! String
                convertedInput.appendAll(stringInput.utf8)
                continue
            }
            if input.isInstance(Type<UInt256>()) {
                let uint256Input = input as! UInt256
                convertedInput.appendAll(uint256Input.toString().utf8)
                continue
            }
            if input.isInstance(Type<[AnyStruct]>()) {
                let anyStructArrayInput = input as! [AnyStruct]
                convertedInput.appendAll(self.convertInputsToUtf8(anyStructArrayInput))
            }
        }

        return convertedInput
    }
}