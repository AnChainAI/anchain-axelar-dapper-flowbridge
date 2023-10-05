import EternalStorage from "../util/EternalStorage.cdc"
import IAxelarExecutable from "../interfaces/IAxelarExecutable.cdc"
import AxelarGateway from "../AxelarGateway.cdc"


// Contract is used to store and call capeabilits of the Axelar Flow Bridge
// This contract replaces the AxelarExecutable contract in the original implementation
pub contract AxelarFlowCaller {
    pub event CapabilityCreated(address: String)
    pub event CapabilityUpdated(address: String)
    pub event CapabilityDeleted(address: String)

    pub fun storeCapeability(capability: Capability<&{IAxelarExecutable.AxelarExecutable}>) {
        EternalStorage._setCapability(capability: capability)
        emit CapabilityCreated(address: capability.address.toString())
    }

    pub fun updateCapability(capability: Capability<&{IAxelarExecutable.AxelarExecutable}>) {
        EternalStorage._setCapability(capability: capability)
        emit CapabilityUpdated(address: capability.address.toString())
    }

    pub fun deleteCapability(capability: Capability<&{IAxelarExecutable.AxelarExecutable}>) {
        EternalStorage._deleteCapability(capability: capability)
        emit CapabilityDeleted(address: capability.address.toString())
    }

    pub fun getCapability(address: String): Capability<&{IAxelarExecutable.AxelarExecutable}>? {
        return EternalStorage._getCapability(contractAddress: address)
    }

    pub fun executeCapability(commandId: String, sourceChain: String, sourceAddress: String, contractAddress: String, payload: String) {
        if(!AxelarGateway.validateContractCall(commandId: commandId, sourceChain: sourceChain, sourceAddress: sourceAddress, contractAddress: contractAddress, payloadHash: payload)){
            panic("Not Approved By Gateway")
        }
        let capability: Capability<&{IAxelarExecutable.AxelarExecutable}>? = EternalStorage._getCapability(contractAddress: contractAddress)
        capability?.execute(sourceChain: sourceChain, sourceAddress: sourceAddress, payload: payload)
    }


}