import AxelarGateway from "../AxelarGateway";
import FungibleToken from "flow-ft";
import Crypto

access(all) contract InterchainTokenService{

    access(all)  let prefixAuthCapabilityName: String
    access(all)  let inboxAccountCapabilityNamePrefix: String

    access(self) let approvedCommands: @{String: ApprovedCommands} 
    access(self) let tokenActions: @{String: TokenActions}

    access(all) let INIT_INTERCHAIN_TRANSFER: [UInt8]

    access(all) resource ApprovedCommands {
        access(all) var destinationAddress: Address
        access(all) var action: String
        access(all) var sourceChain: String
        access(all) var soruceAddress: String
        access(all) var payload: [UInt8]


        init(destinationAddress: Address, action: String, sourceChain: String, sourceAddress: String, payload: [UInt8]){
            self.destinationAddress = destinationAddress
            self.action = action
            self.sourceChain = sourceChain
            self.soruceAddress = sourceAddress
            self.payload = payload
        }
    }

    access(all) resource TokenActions{
        access(self) let contractAddress: Address
        access(self) let contractName: String
        access(self) let authAccountCapability: Capability<&AuthAccount>
        access(self) let adminCapability: Capability<&{FungibleToken.Administrator}>
        access(self) let minterCapability: Capability<&{FungibleToken.Minter}>
        access(self) let burnerCapability: Capability<&{FungibleToken.Burner}>

        init(
            contractName: String,
            authAccountCapability: Capability<&AuthAccount>,
            adminCapability: Capability<&{FungibleToken.Administrator}>,
        ) {
            // Validate given Capability
            if !authAccountCapability.check() {
                panic("Account capability is invalid for account: ".concat(authAccountCapability.address.toString()))
            }
            self.contractAddress = authAccountCapability.borrow()!.address
            self.contractName = contractName
            self.authAccountCapability = authAccountCapability
            self.adminCapability = adminCapability
            self.minterCapability <- adminCapability.createNewMinter()
            self.burnerCapability <- adminCapability.createNewBurner()
        }
    }

    access(all) event InterchainTransfer(
        tokenId: String,
        sourceAddress: Address,
        destinationChain: String,
        amount: UFix64,
        datahash: String
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

    init(){
        self.approvedCommands <- {}
        self.tokenActions <- {}
        self.prefixAuthCapabilityName = "GovernanceUpdaterCapability_"
        self.inboxAccountCapabilityNamePrefix = "GovernanceUpdaterInbox_"
    }


   access(all) fun interchainTransfer(contractName: String, contractAddress: Address, destinationChain: String, destinationAddress: String, vault: @FungibleToken.Vault, metadata: [UInt8]){
        let tokenHash = self.createTokenHash(contractName: contractName, address: contractAddress)
        let amount = vault.balance

   }

   access(self) fun _transmitInterchainTransfer(){

   }

   access(all) resource ExecutableResource: AxelarGateway.Executable, AxelarGateway.SenderIdentity {
        access(all) fun executeApp(commandResource: &AxelarGateway.CGPCommand, sourceChain: String, sourceAddress: String, payload: [UInt8]): AxelarGateway.ExecutionStatus{
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

    access(self) fun claimAuthCapability(provider: Address, contractName: String): &TokenActions? {
        if let authCapability: Capability<&AuthAccount> = self.account.inbox.claim<&AuthAccount>(self.inboxAccountCapabilityNamePrefix.concat(provider.toString()), provider: provider) {
            let resourcePath = self.getAuthCapabilityStoragePath(provider) ?? panic("Could not get auth capability path for address ".concat(provider.toString()))
            let oldCapability <- self.account.load<@TokenActions>(from: resourcePath)
            destroy oldCapability
            let contract = authCapability.contracts.get(name: contractName)
            let adminCapability = contract.getAdminCapability()
            let tokenActions <- create TokenActions(contractName: contractName, authAccountCapability: authCapability, adminCapability: adminCapability)
            
            self.account.save(<-tokenActions, to: resourcePath)
            return self.account.borrow<&Updater>(from: resourcePath)
        }
        return nil
    }

    access(all) fun getAuthCapabilityStoragePath(_ address: Address): StoragePath? {
        return StoragePath(identifier: self.prefixAuthCapabilityName.concat(address.toString()))
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