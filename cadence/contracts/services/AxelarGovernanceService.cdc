import AxelarGateway from "../AxelarGateway.cdc"
import FungibleToken from "FungibleToken"
import Crypto

pub contract AxelarGovernanceService{
    access(all) let inboxHostAccountCapPrefix: String
    access(all) let prefixHostAccountCap: String
    //Paths
    access(all) let UpdaterContractAccountPrivatePath: PrivatePath
    access(all) let HostStoragePath: StoragePath

    //Selectors
    access(self) let SELECTOR_SCHEDULE_PROPOSAL: [UInt8]
    access(self) let SELECTOR_CANCEL_PROPOSAL: [UInt8]

    // Global Contract Variables
    access(all) let gateway: Address
    access(all) let governanceChain: String
    access(all) let governanceAddress: String
    access(all) let minimumTimeDelay: UInt64
    access(self) let updaters: @{Address: Updater}
    access(self) let proposals: @{String: Proposal}

    // Struct representing Contract Updates
    pub struct ContractUpdate {
        pub let address: Address
        pub let name: String
        pub let code: String

        init(address: Address, name: String, code: String) {
            self.address = address
            self.name = name
            self.code = code
        }

        /// Serializes the address and name into a string
        pub fun toString(): String {
            return self.address.toString().concat(".").concat(self.name)
        }

        /// Returns code as a String
        pub fun codeAsCadence(): String {
            return String.fromUTF8(self.code.decodeHex()) ?? panic("Problem stringifying code!")
        }
    }

    /*************\
    |* Resources *|
    \*************/
    //Proposal Resource
    access(all) resource Proposal{
        access(contract) let id: String
        access(contract) let proposedUpdate: ContractUpdate
        access(contract) let target: Address
        access(contract) let timeCreated: UInt64
        access(contract) let timeToExecute: UInt64
        access(contract) var executed: Bool

        init(id: String, proposedCode: String, target: Address, contractName: String, timeToExecute: UInt64){
        pre {
            getAccount(target).contracts.names.contains(contractName): "Target does not currently host the named contract"
        }
            self.id = id
            self.target = target
            self.proposedUpdate = ContractUpdate(address: target, name: contractName, code: proposedCode)  
            self.timeCreated = UInt64(getCurrentBlock().timestamp)
            self.executed = false

            if timeToExecute < UInt64(getCurrentBlock().timestamp) + AxelarGovernanceService.minimumTimeDelay {
                self.timeToExecute = UInt64(getCurrentBlock().timestamp) + AxelarGovernanceService.minimumTimeDelay
            } else {
                self.timeToExecute = timeToExecute
            }
        }

        access(all) fun getTimeToExecute(): UInt64{
            return self.timeToExecute
        }

        access(contract) fun execute(){
            let updaterPath = AxelarGovernanceService.getUpdaterStoragePath(forAddress: self.target) ?? panic("Could not get app capability path for address ".concat(self.target.toString()))
            var updater: &AxelarGovernanceService.Updater? = AxelarGovernanceService.account.borrow<&AxelarGovernanceService.Updater>(from: updaterPath)
            if updater == nil {
                updater = AxelarGovernanceService.claimAuthCapability(provider: self.target)
            }
            if updater == nil{
                panic("Cannot retrieve Updater for target address to execute this Proposal")
            }
            updater!.update(code: self.proposedUpdate.code.decodeHex(), contractName: self.proposedUpdate.name)
            self.executed = true
        }

    }

    //Host Resource
    access(all) resource Host {
        access(self) let accountCapability: Capability<&AuthAccount>

        init(accountCapability: Capability<&AuthAccount>) {
            self.accountCapability = accountCapability
        }

        /// Updates the contract with the specified name and code
        ///
        access(all) fun update(name: String, code: [UInt8]): Bool {
            if let account = self.accountCapability.borrow() {
                // TODO: Replace update__experimental with tryUpdate() once it's available
                // let deploymentResult = account.contracts.tryUpdate(name: name, code: code)
                // return deploymentResult.success
                account.contracts.update__experimental(name: name, code: code)
                return true
            }
            return false
        }

        /// Checks the wrapped AuthAccount Capability
        ///
        access(all) fun checkAccountCapability(): Bool {
            return self.accountCapability.check()
        }

        /// Returns the Address of the underlying account
        ///
        access(all) fun getHostAddress(): Address? {
            return self.accountCapability.borrow()?.address
        }
    }

    //Updater Resource
    access(all) resource Updater{
        access(self) let address: Address
        access(self) let hostAccountCap: Capability<&Host>

        init(
            hostAccountCap: Capability<&Host>,
        ) {
            // Validate given Capability
            if !hostAccountCap.check() {
                panic("Host Account capability is invalid for account: ".concat(hostAccountCap.address.toString()))
            }
            self.hostAccountCap = hostAccountCap
            let hostAccount = self.hostAccountCap.borrow()!
            self.address = hostAccount.getHostAddress() ?? panic("Host has invalid account capability")
            

        }

        access(contract) fun update(code: [UInt8], contractName: String): Bool {
            return self.hostAccountCap.borrow()?.update(name: contractName, code: code) ?? false
        }
    }



    /**********\
    |* Events *|
    \**********/

    pub event ProposalScheduled(
        proposalHash: String,
        target: Address,
        proposedCode: String,
        eta: UInt64
    )

    pub event ProposalCancelled(
        proposalHash: String,
        target: Address,
        proposedCode: String,
        eta: UInt64
    )

    pub event ProposalExecuted(
        proposalHash: String,
        target: Address,
        proposedCode: String,
        timestamp: UInt64
    )


    init(gateway: Address, governanceChain: String, governanceAddress: String, minimumTimeDelay: UInt64){
        if (governanceChain.length == 0 || governanceAddress.length == 0){
            panic("InvalidAddress")
        }


        self.gateway = gateway
        self.governanceChain = governanceChain
        self.governanceAddress = governanceAddress
        self.minimumTimeDelay = minimumTimeDelay
        self.SELECTOR_SCHEDULE_PROPOSAL = Crypto.hash("scheduleProposal".utf8, algorithm: HashAlgorithm.KECCAK_256)
        self.SELECTOR_CANCEL_PROPOSAL = Crypto.hash("cancelProposal".utf8, algorithm: HashAlgorithm.KECCAK_256)
        self.inboxHostAccountCapPrefix = "GovernanceUpdaterInbox_"
        self.prefixHostAccountCap = "GovernanceUpdaterCapability_"
        self.HostStoragePath = StoragePath(identifier: "HostAccount_".concat(self.account.address.toString()))!
        self.UpdaterContractAccountPrivatePath = PrivatePath(identifier: "UpdaterContractAccount_".concat(self.account.address.toString()))!
        self.updaters <- {}
        self.proposals <- {}

        let axelarExecutable <- create ExecutableResource()
        self.account.save(<-axelarExecutable, to: /storage/AxelarExecutable)
    }

    
    //Get estimated execution time for proposal
    access(all) fun getProposalEta(proposedCode: String, target: Address): UInt64{
        let proposalHash: String = String.encodeHex(self.createProposalHash(proposedCode: proposedCode, target: target))
        return self.proposals[proposalHash]?.getTimeToExecute()!
    }

    access(all) fun getProposal(propsosalHash: String): AnyStruct {
        return {
                "id": self.proposals[propsosalHash]?.id,  
                "target": self.proposals[propsosalHash]?.target,
                "proposedUpdate": self.proposals[propsosalHash]?.proposedUpdate,
                "timeCreated": self.proposals[propsosalHash]?.timeCreated,
                "timeExecuted": self.proposals[propsosalHash]?.timeToExecute,
                "executed": self.proposals[propsosalHash]?.executed
            }    
    }

    //Execute Scheduled Proposal
    access(all) fun executeProposal(proposedCode: String, target: Address){
        let proposalHash: String = String.encodeHex(self.createProposalHash(proposedCode: proposedCode, target: target))
        //check for time left in propsoal
        if(self.proposals[proposalHash]?.getTimeToExecute()! <= UInt64(getCurrentBlock().timestamp)){
            //Execute Proposal
            self.proposals[proposalHash]?.execute()

            emit ProposalExecuted(
                proposalHash: proposalHash,
                target: target,
                proposedCode: proposedCode,
                timestamp: UInt64(getCurrentBlock().timestamp)
            )

            destroy <- self.proposals.remove(key: proposalHash)
        } else { 
            panic("ProposalNotReady")
        }
    }

    access(all) resource ExecutableResource: AxelarGateway.Executable, AxelarGateway.SenderIdentity {
        access(all) fun executeApp(commandResource: &AxelarGateway.CGPCommand, sourceChain: String, sourceAddress: String, payload: [UInt8], receiver: &{FungibleToken.Receiver}?): AxelarGateway.ExecutionStatus{
            if (sourceChain != AxelarGovernanceService.governanceChain || sourceAddress != AxelarGovernanceService.governanceAddress){
                panic("Not Governance")
            }


            // let commandSelector = payload[0]
            // let target = Address.fromBytes(payload[1])
            // let proposedCode = String.fromUTF8(payload[2])!
            // let timeToExecute = UInt64.fromString(String.fromUTF8(payload[3])!)!
            // let contractName = String.encodeHex(payload[4])

            //defining as constants untill abiencode/decode is included
            let commandSelector = AxelarGovernanceService.SELECTOR_SCHEDULE_PROPOSAL
            let target: Address= AxelarGovernanceService.gateway
            let proposedCode = String.fromUTF8(payload)!
            let timeToExecute = 0 as UInt64
            let contractName = "AxelarGateway"

            AxelarGovernanceService._processCommand(commandSelector: commandSelector, proposedCode: proposedCode, target: target, timeToExecute: timeToExecute, contractName: contractName)
            return AxelarGateway.ExecutionStatus(
                isExecuted: true,
                statusCode: 0,
                errorMessage: ""
            )
        }
    }

    //Process Command coming from Gateway
    access(contract) fun _processCommand(commandSelector: [UInt8] ,proposedCode: String, target: Address, timeToExecute: UInt64, contractName: String){
        let proposalHash = String.encodeHex(self.createProposalHash(proposedCode: proposedCode, target: target))
        if (commandSelector == self.SELECTOR_SCHEDULE_PROPOSAL){
            self.proposals[proposalHash] <-! create Proposal(id: proposalHash, proposedCode: proposedCode, target:target, contractName: contractName, timeToExecute: timeToExecute)
            emit ProposalScheduled(
                proposalHash: proposalHash,
                target: target,
                proposedCode: proposedCode,
                eta: timeToExecute
            )
        }else if (commandSelector == self.SELECTOR_CANCEL_PROPOSAL){
            destroy <- self.proposals.remove(key: proposalHash)
            
            emit ProposalCancelled(
                proposalHash: proposalHash,
                target: target,
                proposedCode: proposedCode,
                eta: timeToExecute
            )
        }else{
            panic("InvalidCommand")
        }
    }

    access(all) fun createNewUpdater(account: Capability<&Host>): @Updater{
        let updater <- create Updater(hostAccountCap: account)
        return <-updater
    }

    access(all) fun createNewHost(accountCap: Capability<&AuthAccount>): @Host {
        return <- create Host(accountCapability: accountCap)
    }

    access(self) fun claimAuthCapability(provider: Address): &Updater? {
        if let hostAccountCap: Capability<&Host> = self.account.inbox.claim<&Host>(self.inboxHostAccountCapPrefix.concat(provider.toString()), provider: provider) {
            let resourcePath = self.getUpdaterStoragePath(forAddress: provider) ?? panic("Could not get Updater StoragePath for address ".concat(provider.toString()))
            let oldUpdater <- self.account.load<@Updater>(from: resourcePath)
            destroy oldUpdater
            let updater <- self.createNewUpdater(account: hostAccountCap)
            self.account.save(<-updater, to: resourcePath)
            return self.account.borrow<&Updater>(from: resourcePath)
        }
        return nil
    }

    access(all) fun getAuthCapabilityStoragePath(_ address: Address): StoragePath? {
        return StoragePath(identifier: self.prefixHostAccountCap.concat(address.toString()))
    }
    

    access(all) fun createProposalHash(proposedCode: String, target: Address): [UInt8]{
        return Crypto.hash(self.convertInputsToUtf8([proposedCode, target]) , algorithm: HashAlgorithm.KECCAK_256)
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