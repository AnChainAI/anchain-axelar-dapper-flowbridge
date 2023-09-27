pub contract EternalStorage {
    access(self) var _boolStorage: {String:Bool}

    // *** Setter Methods ***
    access(account) fun _setBool(key: String, value: Bool) {
        EternalStorage._boolStorage[key] = value
    }

    // *** Delete Methods ***
    access(account) fun _deleteBool(key: String) {
        EternalStorage._boolStorage.remove(key: key)
    }

    // *** Getter Methods ***
    pub fun getBool(key: String): Bool {
        return self._boolStorage[key] ?? false
    }

    init() {
        self._boolStorage = {}
    }
}
