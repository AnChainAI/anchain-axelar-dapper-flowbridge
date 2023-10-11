import { AxelarAuthWeightedContract } from './contracts/axelar-auth-weighted.contract'
import { IAxelarExecutableContract } from './contracts/i-axelar-executable.contract'
import { dataToHexEncodedMessage } from './utils/data-to-hex-encoded-message'
import { AxelarGatewayContract } from './contracts/axelar-gateway.contract'
import { Emulator, FlowAccount, EMULATOR_CONST } from '../utils/testing'
import { deployAuthContract } from './transactions/deploy-auth-contract'
import { getDeployedContracts } from './scripts/get-deployed-contracts'
import { deployContracts } from './transactions/deploy-contracts'
import { callContract } from './transactions/call-contract'
import { execute } from './transactions/execute'
import { FlowConstants } from '../utils/flow'
import { randomUUID } from 'crypto'
import { ethers } from 'hardhat'
import { sortBy } from 'lodash'

// npm test -- gateway.spec.ts
describe('AxelarGateway', () => {
  const defaultAbiCoder = ethers.AbiCoder.defaultAbiCoder()
  const wallets = Array.from({ length: 10 }).map(() =>
    ethers.Wallet.createRandom(),
  )
  const keccak256 = ethers.keccak256
  const encoder = new TextEncoder()
  const user = wallets[0]
  const threshold = 7
  const operators = sortBy(wallets.slice(0, threshold), (wallet) =>
    wallet.signingKey.publicKey.slice(4),
  )
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
          contracts: [iAxelarExecutableContract],
        },
        authz: admin.authz,
      })
      await deployAuthContract({
        args: {
          contractName: axelarAuthWeightedContract.name,
          contractCode: axelarAuthWeightedContract.code,
          recentOperators: operators.map((operator) =>
            operator.signingKey.publicKey.slice(4),
          ),
          recentWeights: operators.map(() => 1),
          recentThreshold: operators.length,
        },
        authz: admin.authz,
      })
      // Deploys dependent smart contracts to admin account
      const axelarGatewayContract = AxelarGatewayContract(admin.addr)
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
          encoder.encode(defaultAbiCoder.encode(['address'], [user.address])),
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

  describe('Approve Contract Call', () => {
    it('should approve a contract call', async () => {
      const payload = defaultAbiCoder.encode(['address'], [user.address])
      const sourceChain = 'Source'
      const sourceAddress = 'address0x123'
      const contractAddress = user.address
      const payloadHash = keccak256(payload)
      const sourceTxHash = keccak256('0x123abc123abc')
      const sourceEventIndex = 17
      const commandId = randomUUID()

      const approveData = dataToHexEncodedMessage(
        [commandId],
        ['approveContractCall'],
        [
          [
            sourceChain,
            sourceAddress,
            contractAddress,
            payloadHash,
            sourceTxHash,
            sourceEventIndex.toString(),
          ],
        ],
      )

      const ethSignatures = await Promise.all(
        sortBy(operators, (wallet) =>
          wallet.signingKey.publicKey.toLowerCase(),
        ).map((wallet) => wallet.signMessage(approveData)),
      )
      const signatures = ethSignatures.map((ethSig) => {
        const removedPrefix = ethSig.replace(/^0x/, '')
        const sigObj = {
          r: removedPrefix.slice(0, 64),
          s: removedPrefix.slice(64, 128),
        }
        return sigObj.r + sigObj.s
      })

      const tx = await execute({
        constants,
        args: {
          commandIds: [commandId],
          commands: ['approveContractCall'],
          params: [
            [
              sourceChain,
              sourceAddress,
              contractAddress,
              payloadHash,
              sourceTxHash,
              sourceEventIndex.toString(),
            ],
          ],
          operators: operators.map((operator) =>
            operator.signingKey.publicKey.slice(4),
          ),
          weights: operators.map(() => 1),
          threshold: operators.length,
          signatures,
        },
        authz: relayer.authz,
      })

      console.log(JSON.stringify(tx, null, 2))
    })
  })
})
