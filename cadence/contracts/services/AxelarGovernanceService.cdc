import IAxelarExecutable from "../AxelarGateway.cdc"
import AxelarGateway from "../AxelarGateway.cdc"

pub contract AxelarGovernanceService: IAxelarExecutable{
    access(all) let gateway: Address
    access(all) let governanceChain: String
    access(all) let governanceAddress: String
    access(all) let minimumTimeDelay: UInt64

    access(all) resource Proposal{
        access(self) let id: String
        access(self) let proposedCode: String
        access(self) let target: Address
        access(self) let timeCreated: UInt64
        access(self) let timeToExecute: UInt64
        access(self) let executed: Bool

        init(id: String, proposedCode: String, target: Address, timeToExecute: UInt64){
            self.id = id
            self.proposedCode = proposedCode
            self.target = target
            self.timeCreated = UInt64(getCurrentBlock().timestamp)
            self.executed = false

            if timeToExecute < UInt64(getCurrentBlock().timestamp) + self.minimumTimeDelay {
                self.timeToExecute = UInt64(getCurrentBlock().timestamp) + self.minimumTimeDelay
            } else {
                self.timeToExecute = timeToExecute
            }
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
        self.gateway = gateway
        self.governanceChain = governanceChain
        self.governanceAddress = governanceAddress
        self.minimumTimeDelay = minimumTimeDelay
    }

    access(self) let proposals: {String: @Proposal}

    access(all) fun getProposalEta(proposedCode: String, target: Address, timeToExecute: UInt64): UInt64{
        let proposalHash = createProposalHash(proposedCode, target, timeToExecute)
        let proposal = self.proposals[proposalHash]
        return proposal.timeToExecute
    }

    access(all) fun executeProposal(proposedCode: String, target: Address, timeToExecute: UInt64){
        let proposalHash = createProposalHash(proposedCode, target, timeToExecute)
        let proposal = self.proposals[proposalHash]
        //check for time left in propsoal
        if(proposal.timeToExecute < UInt64(getCurrentBlock().timestamp)){
            //TODO: execute proposal
            proposal.executed = true
        } else {
            //TODO: throw error
        }
    }

    access(all) resource execute: AxelarGateway.Exetable{
        access(all) fun executeApp(commandResource: &AxelarGateway.CGPCommand, sourceChain: String, sourceAddress: String, payload: [UInt8]){

            //check if its an execute proposal command

            //check if the proposal is ready to be executed
                //if so, execute it
        }
    }

    

    access(all) fun createProposalHash(proposedCode: String, target: Address, timeToExecute: UInt64): String{
        return sha3(proposedCode + target.toString() + timeToExecute.toString())
    }


    


}