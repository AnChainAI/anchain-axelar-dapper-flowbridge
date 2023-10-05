import { AxelarAuthWeightedContract } from './contracts/axelar-auth-weighted.contract'
import { IAxelarExecutableContract } from './contracts/i-axelar-executable.contract'
import { EternalStorageContract } from './contracts/eternal-storage.contract'
import { AxelarGatewayContract } from './contracts/axelar-gateway.contract'
import { Emulator, FlowAccount, EMULATOR_CONST } from '../utils/testing'
import { getDeployedContracts } from './scripts/get-deployed-contracts'
import { deployContracts } from './transactions/deploy-contracts'
import { FlowConstants } from '../utils/flow'

// npm test -- gateway.spec.ts
describe('AxelarGateway', () => {
  let constants: FlowConstants
  let admin: FlowAccount

  beforeAll(async () => {
    await Emulator.connect()
  })

  it('deploy contracts to admin account', async () => {
    // Create an admin account
    admin = await FlowAccount.from({})

    // Update Flow Constants with admin address
    constants = { ...EMULATOR_CONST, FLOW_ADMIN_ADDRESS: admin.addr }

    // Deploys independent smart contracts to admin account
    const iAxelarExecutableContract = IAxelarExecutableContract()
    const axelarAuthWeightedContract = AxelarAuthWeightedContract()
    await deployContracts({
      args: {
        contracts: [iAxelarExecutableContract, axelarAuthWeightedContract],
      },
      authz: admin.authz,
    })
    // Deploys dependent smart contracts to admin account
    const eternalStorageContract = EternalStorageContract(admin.addr)
    const axelarGatewayContract = AxelarGatewayContract(admin.addr)
    await deployContracts({
      args: {
        contracts: [eternalStorageContract],
      },
      authz: admin.authz,
    })
    await deployContracts({
      args: {
        contracts: [axelarGatewayContract],
      },
      authz: admin.authz,
    })

    // Get the deployed contracts on the admin account
    const deployedContracts = await getDeployedContracts({
      args: { address: admin.addr },
    })

    expect(deployedContracts).toEqual([
      'AxelarAuthWeighted',
      'AxelarGateway',
      'EternalStorage',
      'IAxelarExecutable',
    ])
  })
})
