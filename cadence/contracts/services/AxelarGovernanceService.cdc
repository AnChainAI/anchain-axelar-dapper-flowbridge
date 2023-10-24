import IAxelarExecutable from "../AxelarGateway.cdc"
import AxelarGateway from "../AxelarGateway.cdc"

pub contract AxelarGovernanceService: IAxelarExecutable{
    access(all) let gateway: Address
    access(all) let governanceChain: String
    access(all) let governanceAddress: String
    access(all) let minimumTimeDelay: UInt64


    init(gateway: Address, governanceChain: String, governanceAddress: String, minimumTimeDelay: UInt64){
        self.gateway = gateway
        self.governanceChain = governanceChain
        self.governanceAddress = governanceAddress
        self.minimumTimeDelay = minimumTimeDelay
    }

    access(all) resource Proposal{
        access(self) let hash: String
        access(self) let proposedCode: String
        access(self) let target: Address
        access(self) let timeCreated: UInt64
        access(self) let timeToExecute: UInt64
        access(self) let executed: Bool

        init(hash: String, proposedCode: String, target: Address, timeToExecute: UInt64){
            self.hash = hash
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

    access(all) fun 



}