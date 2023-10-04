import IAxelarExecutable from "../interfaces/IAxelarExecutable.cdc"

pub contract EternalStorage {
    access(self) let _appCapabilities: {String: Capability<&{IAxelarExecutable.AxelarExecutable}>}
    access(self) var _boolStorage: {String: Bool}

    /********************\
    |* Internal Methods *|
    \********************/
    access(account) fun _setCapability(capability: Capability<&{IAxelarExecutable.AxelarExecutable}>) {
        self._appCapabilities[capability.address.toString()] = capability
    }

    access(account) fun _setBool(key: String, value: Bool) {
        self._boolStorage[key] = value
    }

    access(account) fun _deleteCapability(contractAddress: String) {
        self._appCapabilities.remove(key: contractAddress)
    }

    access(account) fun _deleteBool(key: String) {
        self._boolStorage.remove(key: key)
    }

    access(account) fun _getCapability(contractAddress: String): Capability<&{IAxelarExecutable.AxelarExecutable}>? {
        return self._appCapabilities[contractAddress]
    }

    /********************\
    |* External Methods *|
    \********************/
    pub fun getBool(key: String): Bool {
        return self._boolStorage[key] ?? false
    }

    init() {
        self._appCapabilities = {}
        self._boolStorage = {}
    }
}

