import AxelarFlowCaller from "../../caller/AxelarFlowCaller.cdc"
import IAxelarExecutable from "../../interface/IAxelarExecutable.cdc"

transaction(externalCap: Capability<&{IAxelarExecutable.AxelarExecutable}>) {
    prepare(signer: AuthAccount) {
        let axelarFlowCallerRef = signer.borrow<&{AxelarFlowCaller}>(from: /public/AxelarFlowCaller)
            ?? panic("Could not borrow reference to AxelarFlowCaller")
        axelarFlowCallerRef.storeCapeability(capability: externalCap)
    }
}
