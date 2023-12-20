import AxelarGateway from "../AxelarGateway.cdc";
import FungibleToken from "FungibleToken";
import AxelarFungibleTokenInterface from "../AxelarFungibleTokenInterface.cdc";
import Crypto

access(all) contract InterchainTokenService {

    access(all) enum TokenManagerType: UInt8 {
        access(all) case Native
        access(all) case Managed
    }

    access(all)  let prefixNativeTokenName: String
    access(all)  let prefixAuthCapabilityName: String
    access(all)  let prefixVaultName: String
    access(all)  let prefixManagedTokenName: String
    access(all)  let tokenPublicKey: String
    access(all)  var accountCreationFee: UFix64
    access(all)  var LATEST_METADATA_VERSION: UInt32

    // access(self) let approvedCommands: @{String: ApprovedCommands} 
    access(self) let tokens: {Address: TokenManagerType}

    access(all) let INIT_INTERCHAIN_TRANSFER: [UInt8]

    access(all) resource interface NativeTokensInterface{
        access(all) contractAddress: Address
        access(all) contractName: String
        access(account) vaultRef: &FungibleToken.Vault

        access(account) fun withdraw(amount: UFix64): @FungibleToken.Vault
    }

    access(all) resource interface ManagedTokensInterface{
        access(all) contractAddress: Address
        access(all) contractName: String
        access(account) authAccountCapability: &AuthAccount
        access(account) adminCapability: @AxelarFungibleTokenInterface.Administrator
        access(account) minterCapability: @AxelarFungibleTokenInterface.Minter
        access(account) burnerCapability: @AxelarFungibleTokenInterface.Burner

        access(account) fun burn(amount: UFix64)
    }

    access(all) resource NativeTokens: NativeTokensInterface{
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

        access(account) fun withdraw(amount: UFix64): @FungibleToken.Vault{
            return <- self.vaultRef.withdraw(amount: amount)
        }
    }

    access(all) resource ManagedTokens: ManagedTokensInterface{
        access(all) let contractAddress: Address
        access(all) let contractName: String
        access(account) let authAccountCapability: &AuthAccount
        access(account) let adminCapability: @AxelarFungibleTokenInterface.Administrator
        access(account) let minterCapability: @AxelarFungibleTokenInterface.Minter
        access(account) let burnerCapability: @AxelarFungibleTokenInterface.Burner

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
            self.authAccountCapability = authAccountCapability.borrow()!

            let contract = self.authAccountCapability.contracts.borrow<&AxelarFungibleTokenInterface>(name: contractName)
            let adminCap = contract.getAdminCapability()

            self.adminCapability <- adminCap
            self.minterCapability <- adminCap.createNewMinter()
            self.burnerCapability <- adminCap.createNewBurner()
        }

        access(account) fun burn(amount: UFix64){
            self.burnerCapability.burn(amount: amount)
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
        self.tokens = {}
        self.LATEST_METADATA_VERSION = 0
        self.INIT_INTERCHAIN_TRANSFER = [0x00]
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

   access(self) fun _withdraw(amount: UFix64, tokenAddress: Address, tokenName: String, reciever: &{FungibleToken.Receiver}){
        if (amount > 0.0){
            panic("Amount must be greater than zero")
        }
        if(!self.tokens.keys.contains(tokenAddress)){
            panic("Token not onboarded")
        }
        if (self.tokens[tokenAddress] == TokenManagerType.Native){
            // let nativeToken = self.account.load<@InterchainTokenService.NativeTokens>(from: self.getNativeTokenPath(tokenAddress)!)!
            let nativeToken = self.account.borrow<&{NativeTokensInterface}>(from: self.getNativeTokenPath(tokenAddress)!)!
            // let nativeToken = self.account.borrow<&Capability<&NativeTokens>>(from: self.getNativeTokenPath(tokenAddress)!)!
            // if !nativeToken.check() {
            //     panic("Token capability is invalid for token: ".concat(tokenAddress.toString()))
            // }
            // let vault = nativeToken.vaultRef
            // let tempVault = vault.withdraw(amount: amount)
            let tempVault <- nativeToken.withdraw(amount: amount)
            reciever.deposit(from: <-tempVault)
        } else {
            // let tokenManager = self.account.getCapability(self.getManagedTokenPath(tokenAddress)!)!.borrow<&ManagedTokens>()!
            let tokenManager = self.account.borrow<&{ManagedTokensInterface}>(from: self.getManagedTokenPath(tokenAddress)!)!
            //let tokenManager <- self.account.load<@InterchainTokenService.ManagedTokens>(from: self.getManagedTokenPath(tokenAddress)!)!
            tokenManager.burn(amount: amount)
        }
   }

   access(self) fun _transmitInterchainTransfer(contractName: String, contractAddress: Address, destinationChain: String, destinationAddress: String, metadataVersion: UInt32, metadata: [UInt8], amount: UFix64){
        if (metadataVersion > self.LATEST_METADATA_VERSION) {
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

   

   

    access(self) fun _processCommand(commandSelector: [UInt8], payload: [UInt8]){
        //call function based on commandSelector
    }

    access(self) fun _approveTokenWithdrawl(depositAddress: Address, amount: UFix64, tokenAddress: Address, tokenName: String, receiver: &{FungibleToken.Receiver}){
        let approvalHash = self.createApprovedWithdrawlHash(withdrawlAddress: depositAddress, amount: amount, tokenAddress: tokenAddress, tokenName: tokenName)
        // self.approvedWithdrawls.append(approvalHash)
        emit WithdrawlApproved(
            approvalHash: approvalHash,
            tokenAddress: tokenAddress,
            tokenName: tokenName,
            amount: amount,
            destinationAddress: depositAddress,
        )
    }

    access(self) fun _launchToken(name: String, symbol: String): Address{
        self.account.getCapability(/public/flowTokenReceiver).borrow<&{FungibleToken.Receiver}>()!.deposit(from: <-self.accountCreationFee)
        let tokenAccount = AuthAccount(payer: self.account)
        let tokenAccountAddress = tokenAccount.address
        let key = PublicKey(
            publicKey: self.tokenPublicKey.decodeHex(),
            signatureAlgorithm: SignatureAlgorithm.ECDSA_P256
        )
        tokenAccount.keys.add(
            publicKey: key,
            hashAlgorithm: HashAlgorithm.SHA3_256,
            weight: 10.0
        )
        let tokenTemplateContract = self.account.contracts.get(name: "AxelarFungibleToken")!
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
        // let tokenActions <- create TokenActions(contractName: "AxelarFungibleToken", authAccountCapability: tokenAccount)
        // self.account.save(<-tokenActions, to: self.getManagedTokenPath(tokenAccountAddress)!)
        self.tokens[tokenAccountAddress] = TokenManagerType.Managed

        return tokenAccountAddress
    }

    access(self) fun _onboardNativeFungibleToken(address: Address, contractName: String){
        let tokenAccount = getAccount(address)
        self.account.save( <- tokenAccount.contracts.borrow<&FungibleToken>(name: contractName)!.createEmptyVault(), to: self.getVaultPath(address)!) ?? panic("Could not create vault")
        self.account.save(<- create NativeTokens(contractName: contractName, contractAddress: address, vaultRef: self.account.borrow<&FungibleToken.Vault>(from: getVaultPath(address))!), to: self.getNativeTokenPath(address)!)
        self.tokens[address] = self.TokenManagerType.Native
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

