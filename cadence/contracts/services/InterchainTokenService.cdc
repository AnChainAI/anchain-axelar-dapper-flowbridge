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

    access(self) let tokens: {Address: TokenManagerType}

    access(self) let nativeTokens: @{Address: NativeTokens}
    access(self) let managedTokens: @{Address: ManagedTokens}

    //Command Selectors
    access(all) let INTERCHAIN_TRANSFER: [UInt8]
    access(all) let DEPLOY_INTERCHAIN_TOKEN: [UInt8]


    access(all) resource NativeTokens{
        access(all) let contractAddress: Address
        access(all) let contractName: String
        access(all) let vaultStoragePath: StoragePath

        init(
            contractName: String,
            contractAddress: Address,
            vaultStoragePath: StoragePath,
        ) {
            self.contractAddress = contractAddress
            self.contractName = contractName
            self.vaultStoragePath = vaultStoragePath
        }
    }

    access(self) fun createNativeTokens(contractName: String, contractAddress: Address, vaultStoragePath: StoragePath): @NativeTokens{
        return <- create NativeTokens(
            contractName: contractName,
            contractAddress: contractAddress,
            vaultStoragePath: vaultStoragePath,
        )
    }

    access(all) resource ManagedTokens{
        access(all) let contractAddress: Address
        access(all) let contractName: String
        access(account) let adminCapability: Capability<&{AxelarFungibleTokenInterface.AdministratorInterface}>
        access(account) let minterCapability: Capability<&{AxelarFungibleTokenInterface.MinterInterface}>
        access(account) let burnerCapability: Capability<&{AxelarFungibleTokenInterface.BurnerInterface}>

        init(
            contractName: String,
            authAccount: AuthAccount,
        ) {
            self.contractAddress = authAccount.address
            self.contractName = contractName

            let contract = authAccount.contracts.borrow<&AxelarFungibleTokenInterface>(name: contractName)
            InterchainTokenService.account.save(<-contract!.createNewAdmin(), to: InterchainTokenService.getAdminCapabilityStoragePath(self.contractAddress)!)
            
            self.adminCapability = InterchainTokenService.account.link<&{AxelarFungibleTokenInterface.AdministratorInterface}>(InterchainTokenService.getAdminCapabilityPrivatePath(self.contractAddress)!, target: InterchainTokenService.getAdminCapabilityStoragePath(self.contractAddress)!)!
            let adminCap = self.adminCapability.borrow()
            InterchainTokenService.account.save(<-adminCap?.createNewMinter(), to: InterchainTokenService.getMinterCapabilityStoragePath(self.contractAddress)!)
            InterchainTokenService.account.save(<-adminCap?.createNewBurner(), to: InterchainTokenService.getBurnerCapabilityStoragePath(self.contractAddress)!)
            self.minterCapability = InterchainTokenService.account.link<&{AxelarFungibleTokenInterface.MinterInterface}>(InterchainTokenService.getMinterCapabilityPrivatePath(self.contractAddress)!, target: InterchainTokenService.getMinterCapabilityStoragePath(self.contractAddress)!)!
            self.burnerCapability = InterchainTokenService.account.link<&{AxelarFungibleTokenInterface.BurnerInterface}>(InterchainTokenService.getBurnerCapabilityPrivatePath(self.contractAddress)!, target: InterchainTokenService.getBurnerCapabilityStoragePath(self.contractAddress)!)!
            
        }

    }

    access(all) event TokenContractLaunched(
        contractName: String,
        contractAddress: Address,
        tokenName: String,
        tokenSymbol: String
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
        params: String
    )

    init(publicKey: String, accountCreationFee: UFix64){
        self.accountCreationFee = accountCreationFee
        self.tokenPublicKey = publicKey
        self.tokens = {}
        self.nativeTokens <- {}
        self.managedTokens <- {}
        self.LATEST_METADATA_VERSION = 0
        self.INTERCHAIN_TRANSFER = Crypto.hash("INTERCHAIN_TRANSFER".utf8, algorithm: HashAlgorithm.KECCAK_256)
        self.DEPLOY_INTERCHAIN_TOKEN = Crypto.hash("DEPLOY_INTERCHAIN_TOKEN".utf8, algorithm: HashAlgorithm.KECCAK_256)
        self.prefixAuthCapabilityName = "TokenAuthCapability_"
        self.prefixNativeTokenName = "NativeToken_"
        self.prefixManagedTokenName = "ManagedToken_"
        self.prefixVaultName = "Vault_"
    }

    access(self) fun changeAccountCreationFee(newFee: UFix64){
        self.accountCreationFee = newFee
    }

    // public interface for initiating interhcain transfer
   access(all) fun interchainTransfer(senderIdentity: Capability<&{AxelarGateway.SenderIdentity}>, contractName: String, contractAddress: Address, destinationChain: String, destinationAddress: String, vault: @FungibleToken.Vault, metadata: [UInt8]){
        pre {
            senderIdentity.check() && senderIdentity.borrow()!.owner != nil: "Cannot borrow reference to SenderIdentity capability"
        }
        let amount = vault.balance
        self._takeToken(tokenAddress: contractAddress, tokenName: contractName, vault: <-vault)

        //TODO: add metadata version check, awaiting ABI encode/decode support

        self._transmitInterchainTransfer(senderIdentity: senderIdentity, contractName: contractName, contractAddress: contractAddress, destinationChain: destinationChain, destinationAddress: destinationAddress, metadataVersion: 0, metadata: metadata, amount: amount)
   }

   access(self) fun _takeToken(tokenAddress: Address, tokenName: String, vault: @FungibleToken.Vault){
        // destroy vault
        // return
        if (self.tokens[tokenAddress] == TokenManagerType.Native){
            // create nativeToken reference
            let nativeToken = (&self.nativeTokens[tokenAddress] as &NativeTokens?) ?? panic("could not borrow native token ref")
            
            //borrow the corresponding native token vault
            let tokenVault = self.account.borrow<&FungibleToken.Vault>(from: nativeToken.vaultStoragePath)!

            //withdraw from vault and deposit to bridge vault
            tokenVault.deposit(from: <-vault)
            return
        } else if self.tokens[tokenAddress] == TokenManagerType.Managed {
            let managedToken = (&self.managedTokens[tokenAddress] as &ManagedTokens?) ?? panic("could not borrow managed token ref")
            let burnCap = managedToken.burnerCapability.borrow()!
            burnCap.burnTokens(from: <- vault)
            return
        }
        destroy vault
        return
   }

   access(self) fun _transmitInterchainTransfer(senderIdentity: Capability<&{AxelarGateway.SenderIdentity}>, contractName: String, contractAddress: Address, destinationChain: String, destinationAddress: String, metadataVersion: UInt32, metadata: [UInt8], amount: UFix64){
        if (metadataVersion > self.LATEST_METADATA_VERSION) {
            panic("Invalid Metadata Version")
        }

        let datahash = Crypto.hash(metadata, algorithm: HashAlgorithm.SHA3_256)

        emit InterchainTransfer(
            tokenAddress: contractAddress,
            tokenName: contractName,
            sourceAddress: senderIdentity.address,
            destinationChain: destinationChain,
            amount: amount,
            datahash: datahash
        )

        //Awaiting ABI.Encode/decode support to parse metadata

        AxelarGateway.callContract(
            senderIdentity: senderIdentity,
            destinationChain: destinationChain,
            destinationContractAddress: destinationAddress,
            payload: metadata
        )
    }

    access(self) fun _processCommand(commandSelector: [UInt8], payload: [UInt8]){
        //call function based on commandSelector
    }

    access(self) fun _withdraw(amount: UFix64, tokenAddress: Address, tokenName: String, reciever: &{FungibleToken.Receiver}){
        if (amount > 0.0){
            panic("Amount must be greater than zero")
        }
        if self.tokens[tokenAddress] == nil {
            panic("Token not onboarded")
        }
        if (self.tokens[tokenAddress] == TokenManagerType.Native){
            // create nativeToken reference
            let nativeToken = (&self.nativeTokens[tokenAddress] as &NativeTokens?) ?? panic("could not borrow native token ref")
            
            //borrow the coresponding native token vault
            let nativeVault = self.account.borrow<&FungibleToken.Vault>(from: nativeToken.vaultStoragePath)
                ?? panic("Could not borrow a reference to the native vault")

            //withdraw from vault and deposit to reciever
            reciever.deposit(from: <-nativeVault.withdraw(amount: amount))
        } else {
            let managedToken = (&self.managedTokens[tokenAddress] as &ManagedTokens?) ?? panic("could not borrow managed token ref")
            let minter = managedToken.minterCapability.borrow()!
            reciever.deposit(from: <-minter.mintTokens(amount: amount)!)
        }
   }

    access(self) fun _launchToken(name: String, symbol: String): Address{
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
        let managedTokens <- create ManagedTokens(contractName: "AxelarFungibleToken", authAccount: tokenAccount)
        self.managedTokens[tokenAccountAddress] <-! managedTokens
        self.tokens[tokenAccountAddress] = TokenManagerType.Managed

        return tokenAccountAddress
    }

    access(self) fun _onboardNativeFungibleToken(address: Address, contractName: String){
        //Get the token account and create an empty vault
        let tokenAccount = getAccount(address)
        let emptyVault <- tokenAccount.contracts.borrow<&FungibleToken>(name: contractName)!.createEmptyVault()
        
        //save empty vault to storage path and store native token resource an dictionary
        self.account.save( <- emptyVault, to: self.getVaultPath(address)!)
        let nativeToken <- self.createNativeTokens(contractName: contractName, contractAddress: address, vaultStoragePath: self.getVaultPath(address)!)
        self.nativeTokens[address] <-! nativeToken
        self.tokens[address] = self.TokenManagerType.Native
    }

    access(all) fun getVaultPath(_ address: Address): StoragePath? {
        return StoragePath(identifier: self.prefixVaultName.concat(address.toString()))
    }

    access(all) fun getAuthCapabilityStoragePath(_ address: Address): StoragePath? {
        return StoragePath(identifier: self.prefixAuthCapabilityName.concat(address.toString()))
    }

    access(all) fun getMinterCapabilityStoragePath(_ address: Address): StoragePath? {
        return StoragePath(identifier: self.prefixAuthCapabilityName.concat(address.toString()).concat("_Minter"))
    }

    access(all) fun getMinterCapabilityPrivatePath(_ address: Address): PrivatePath? {
        return PrivatePath(identifier: self.prefixAuthCapabilityName.concat(address.toString()).concat("_Minter"))
    }

    access(all) fun getBurnerCapabilityStoragePath(_ address: Address): StoragePath? {
        return StoragePath(identifier: self.prefixAuthCapabilityName.concat(address.toString()).concat("_Burner"))
    }

    access(all) fun getBurnerCapabilityPrivatePath(_ address: Address): PrivatePath? {
        return PrivatePath(identifier: self.prefixAuthCapabilityName.concat(address.toString()).concat("_Burner"))
    }

    access(all) fun getAdminCapabilityStoragePath(_ address: Address): StoragePath? {
        return StoragePath(identifier: self.prefixAuthCapabilityName.concat(address.toString()).concat("_Admin"))
    }

    access(all) fun getAdminCapabilityPrivatePath(_ address: Address): PrivatePath? {
        return PrivatePath(identifier: self.prefixAuthCapabilityName.concat(address.toString()).concat("_Admin"))
    }

    access(all) fun createTokenHash(contractName: String, address: Address): [UInt8]{
        return Crypto.hash(self.convertInputsToUtf8([contractName, address]) , algorithm: HashAlgorithm.KECCAK_256)
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

