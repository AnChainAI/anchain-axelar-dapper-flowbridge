import IAxelarExecutable from "../AxelarGateway.cdc"
import AxelarGateway from "../AxelarGateway.cdc"
import Crypto

pub contract AxelarGovernanceService{
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

    //Struct for Contract Updates
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
            AxelarGovernanceService.updaters[self.target]?.update(code: self.proposedUpdate.codeAsCadence(), contractName: self.proposedUpdate.name)
            self.executed = true
        }

    }

    //Updater Resource
    access(all) resource Updater{
        access(self) let address: Address
        access(self) let authCapability: Capability<&AuthAccount>
        access(self) let failedDeployments: {Int: [String]}

        init(
            authCapability: Capability<&AuthAccount>,
        ) {
            // Validate given Capability
            if !authCapability.check() {
                panic("Account capability is invalid for account: ".concat(authCapability.address.toString()))
            }
            self.address = authCapability.borrow()!.address
            self.authCapability = authCapability
 

            self.failedDeployments = {}
        }

        access(contract) fun update(code: String, contractName: String): Bool {
            //going to need to check if the deployment is in the deployments array
            if let account = self.authCapability.borrow() {
                account.contracts.update__experimental(name: contractName, code: code.decodeHex())
            }
            return true
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
        self.updaters <- {}
        self.proposals <- {}
    }

    
    //Get estimated execution time for proposal
    access(all) fun getProposalEta(proposedCode: String, target: Address, timeToExecute: UInt64): UInt64{
        let proposalHash: String = String.fromUTF8(self.createProposalHash(proposedCode: proposedCode, target: target, timeToExecute: timeToExecute))!
        return self.proposals[proposalHash]?.getTimeToExecute()!
    }

    //Execute Scheduled Proposal
    access(all) fun executeProposal(proposedCode: String, target: Address, timeToExecute: UInt64){
        let proposalHash: String = String.fromUTF8(self.createProposalHash(proposedCode: proposedCode, target: target, timeToExecute: timeToExecute))!
        //check for time left in propsoal
        if(self.proposals[proposalHash]?.getTimeToExecute()! < UInt64(getCurrentBlock().timestamp)){
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

    access(all) resource ExecutabeResource: AxelarGateway.Executable{
        access(all) fun executeApp(commandResource: &AxelarGateway.CGPCommand, sourceChain: String, sourceAddress: String, payload: [[UInt8]]){
            if (sourceChain != AxelarGovernanceService.governanceChain || sourceAddress != AxelarGovernanceService.governanceAddress){
                panic("Not Governance")
            }


            let commandSelector = payload[0]
            let target = Address.fromBytes(payload[1])
            let proposedCode = String.fromUTF8(payload[2])!
            let timeToExecute = UInt64.fromString(String.fromUTF8(payload[3])!)!
            let contractName = String.encodeHex(payload[4])

            AxelarGovernanceService._processCommand(commandSelector: commandSelector, proposedCode: proposedCode, target: target, timeToExecute: timeToExecute, contractName: contractName)
        }
    }

    //Process Command coming from Gateway
    access(contract) fun _processCommand(commandSelector: [UInt8] ,proposedCode: String, target: Address, timeToExecute: UInt64, contractName: String){
        let proposalHash = String.encodeHex(self.createProposalHash(proposedCode: proposedCode, target: target, timeToExecute: timeToExecute))
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

    

    access(all) fun createProposalHash(proposedCode: String, target: Address, timeToExecute: UInt64): [UInt8]{
        return Crypto.hash(self.convertInputsToUtf8([proposedCode, target, timeToExecute]) , algorithm: HashAlgorithm.KECCAK_256)
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