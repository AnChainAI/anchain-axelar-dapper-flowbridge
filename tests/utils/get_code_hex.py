import sys

def get_code_hex(contract_path):
    with open(contract_path, "r") as contract_file:
        return bytes(contract_file.read(), "UTF-8").hex()

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 get_code_hex.py <contract_path>")
        sys.exit()
    print(get_code_hex(sys.argv[1]))

if __name__ == "__main__":
    main()