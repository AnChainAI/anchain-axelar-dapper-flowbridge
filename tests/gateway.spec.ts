import { AxelarAuthWeightedContract } from './contracts/axelar-auth-weighted.contract'
import { IAxelarExecutableContract } from './contracts/i-axelar-executable.contract'
import { EternalStorageContract } from './contracts/eternal-storage.contract'
import { AxelarGatewayContract } from './contracts/axelar-gateway.contract'
import { Emulator, FlowAccount, EMULATOR_CONST } from '../utils/testing'
import { getDeployedContracts } from './scripts/get-deployed-contracts'
import { deployContracts } from './transactions/deploy-contracts'
import { callContract } from './transactions/call-contract'
import { FlowConstants } from '../utils/flow'

// npm test -- gateway.spec.ts
describe('AxelarGateway', () => {
  const encoder = new TextEncoder()
  let constants: FlowConstants
  let relayer: FlowAccount
  let admin: FlowAccount

  beforeAll(async () => {
    await Emulator.connect()
  })

  describe('Deploy Contracts', () => {
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

  describe('Call Contract', () => {
    it('should emit call contract event', async () => {
      // Create a relayer account for sending transactions
      relayer = await FlowAccount.from({})

      // Create input params for callContract
      const data = {
        destinationChain: 'Destination',
        destinationContractAddress: '0x123abc',
        payload: Array.from(
          encoder.encode(JSON.stringify({ address: relayer.addr })),
        ),
      }

      // Send callContract transaction
      const tx = await callContract({
        constants,
        args: data,
        authz: relayer.authz,
      })

      // Expect that an event is emitted and input params matching
      expect(tx.events).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            type: `A.${admin.addr.slice(2)}.AxelarGateway.ContractCall`,
            data: expect.objectContaining({
              sender: relayer.addr,
              destinationChain: data.destinationChain,
              destinationContractAddress: data.destinationContractAddress,
              payload: expect.arrayContaining(
                data.payload.map((n) => n.toString()),
              ),
            }),
          }),
        ]),
      )
    })
  })
})
