pub contract EternalStorage {
    pub let EternalStorageManagerPath: StoragePath
    access(self) var _boolStorage: {String:Bool}

    pub resource EternalStorageManager {
        // *** Setter Methods ***
        pub fun _setBool(key: String, value: Bool) {
            EternalStorage._boolStorage[key] = value
        }

        // *** Delete Methods ***
        pub fun _deleteBool(key: String) {
            EternalStorage._boolStorage.remove(key: key)
        }
    }

    // *** Getter Methods ***
    pub fun getBool(key: String): Bool {
        return self._boolStorage[key] ?? false
    }

    init() {
        self.EternalStorageManagerPath = /storage/EternalStorageManagerPath
        self.account.save(<- create EternalStorageManager(), to: self.EternalStorageManagerPath)
        self._boolStorage = {}
    }
}
