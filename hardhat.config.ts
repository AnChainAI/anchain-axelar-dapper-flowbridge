import { HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox'

const config: HardhatUserConfig = {
  solidity: '0.8.9',
  paths: {
    artifacts: './generated/artifacts',
    cache: './generated/cache',
    sources: './contracts',
  },
  networks: {
    localhost: {
      url: 'http://127.0.0.1:8545',
    },
  },
}

export default config
