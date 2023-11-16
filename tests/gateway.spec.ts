import { publishExecutableCapability } from './transactions/publish-executable-capability'
import { AxelarAuthWeightedContract } from './contracts/axelar-auth-weighted.contract'
import { ExampleApplicationContract } from './contracts/example-application.contract'
import { getWeightedSignatureProof } from './utils/get-weighted-signatures-proof'
import { dataToHexEncodedMessage } from './utils/data-to-hex-encoded-message'
import { AxelarGatewayContract } from './contracts/axelar-gateway.contract'
import { Emulator, FlowAccount, EMULATOR_CONST } from '../utils/testing'
import { deployAuthContract } from './transactions/deploy-auth-contract'
import { getDeployedContracts } from './scripts/get-deployed-contracts'
import { getApprovedCommandData } from './scripts/get-example-app-data'
import { deployContracts } from './transactions/deploy-contracts'
import { callContract } from './transactions/call-contract'
import { executeApp } from './transactions/execute-app'
import { execute } from './transactions/execute'
import { FlowConstants } from '../utils/flow'
import { randomUUID } from 'crypto'
import { ethers } from 'hardhat'
import { sortBy } from 'lodash'
import util from 'util'
import { AxelarGovernanceServiceContract } from './contracts/axelar-governance-service.contract'
import { deployGovernanceContract } from './transactions/deploy-governance-contract'
import { getProposalEta } from './scripts/get-proposal-eta'
import { executeGovernanceProposal } from './transactions/execute-governance-proposal'
import { getContractCode } from './scripts/get-contract-code'
import { publishAuthCapabilityToGovernance } from './transactions/publish-auth-capability'
import { AxelarGatewayUpdateContract } from './contracts/axelar-gateway-updated.contract'
import { exec } from 'child_process'
import fs from 'fs'
/**
 * To setup the testing, make sure you've run
 * the following command to start the flow emulator on a separate terminal:
 *
 *  flow emulator
 *
 * To run this testing suite, open a different terminal
 * from the flow emulator terminal, and run the following command:
 *
 *  npm test -- gateway.spec.ts
 */

export const delay = (milliseconds: number, fn: Function) => {
  setTimeout(() => {
    fn()
  }, milliseconds)
}
describe('AxelarGateway', () => {
  const defaultAbiCoder = ethers.AbiCoder.defaultAbiCoder()
  const utilsAddress = '0xf8d6e0586b0a20c7'
  const wallets = Array.from({ length: 10 }).map(() =>
    ethers.Wallet.createRandom()
  )
  const keccak256 = ethers.keccak256
  const encoder = new TextEncoder()
  const user = wallets[0]
  const threshold = 7
  const operators = sortBy(wallets.slice(0, threshold), (wallet) =>
    wallet.signingKey.publicKey.slice(4)
  )
  let constants: FlowConstants
  let dAppUser: FlowAccount
  let relayer: FlowAccount
  let admin: FlowAccount
  let governanceUser: FlowAccount

  beforeAll(async () => {
    await Emulator.connect()
  })

  describe('Deploy Core Contracts', () => {
    it('deploy core contracts to admin account', async () => {
      // Create an admin account
      admin = await FlowAccount.from({})

      // Update Flow Constants with admin address
      constants = { ...EMULATOR_CONST, FLOW_ADMIN_ADDRESS: admin.addr }

      // Deploys independent smart contracts to admin account
      const axelarAuthWeightedContract = AxelarAuthWeightedContract()
      await deployAuthContract({
        args: {
          contractName: axelarAuthWeightedContract.name,
          contractCode: axelarAuthWeightedContract.code,
          recentOperators: operators.map((operator) =>
            operator.signingKey.publicKey.slice(4)
          ),
          recentWeights: operators.map(() => 1),
          recentThreshold: operators.length,
        },
        authz: admin.authz,
      })
      // Deploys dependent smart contracts to admin account
      const axelarGatewayContract = AxelarGatewayContract(
        admin.addr,
        utilsAddress
      )
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

      expect(deployedContracts).toEqual(['AxelarAuthWeighted', 'AxelarGateway'])
    })
  })

  describe('Onboard dApp Contract With Gateway', () => {
    it('deploy an example application contract to dApp account', async () => {
      // Create dApp account
      dAppUser = await FlowAccount.from({})

      // Deploys example application smart contracts to dApp account
      const gatewayAddress = admin.addr
      const exampleApplicationContract = ExampleApplicationContract(
        gatewayAddress
      )
      await deployContracts({
        args: {
          contracts: [exampleApplicationContract],
        },
        authz: dAppUser.authz,
      })

      // Get the deployed contracts on the dApp account
      const deployedContracts = await getDeployedContracts({
        args: { address: dAppUser.addr },
      })

      expect(deployedContracts).toEqual(['ExampleApplication'])
    })

    it("publishes an AxelarGateway Executable capability to the gateway' inbox", async () => {
      // Publishes the dApp executable capability to Gateway's inbox
      let tx = await publishExecutableCapability({
        constants,
        args: {
          recipient: admin.addr,
        },
        authz: dAppUser.authz,
      })

      // Expect that an InboxValuePublished event is emitted with the correct recipient and provider
      expect(tx.events).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            type: 'flow.InboxValuePublished',
            data: expect.objectContaining({
              provider: dAppUser.addr,
              recipient: admin.addr,
              name: `AppCapabilityPath${dAppUser.addr}`,
            }),
          }),
        ])
      )
    })
  })

  describe('Call Contract', () => {
    it('should emit call contract event', async () => {
      // Create input params for callContract
      const data = {
        destinationChain: 'Destination',
        destinationContractAddress: '0x123abc',
        payload: Array.from(
          encoder.encode(defaultAbiCoder.encode(['address'], [user.address]))
        ),
      }

      // Send callContract transaction
      const tx = await callContract({
        constants,
        args: data,
        authz: dAppUser.authz,
      })

      // Expect that an event is emitted and input params matching
      expect(tx.events).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            type: `A.${admin.addr.slice(2)}.AxelarGateway.ContractCall`,
            data: expect.objectContaining({
              sender: dAppUser.addr,
              destinationChain: data.destinationChain,
              destinationContractAddress: data.destinationContractAddress,
              payload: expect.arrayContaining(
                data.payload.map((n) => n.toString())
              ),
            }),
          }),
        ])
      )
    })
  })

  describe('Approve Contract Call and Call Executable Method', () => {
    let payload: Uint8Array
    let sourceChain: string
    let sourceAddress: string
    let contractAddress: string
    let payloadHash: string
    let sourceTxHash: string
    let sourceEventIndex: number
    let commandId: string

    it('should approve a contract call', async () => {
      // Create a relayer account for relaying messages with transactions
      relayer = await FlowAccount.from({})

      // Generate transaction data
      payload = encoder.encode(JSON.stringify({ address: dAppUser.addr }))
      sourceChain = 'Source'
      sourceAddress = 'address0x123'
      contractAddress = dAppUser.addr
      payloadHash = keccak256(payload)
      sourceTxHash = keccak256('0x123abc123abc')
      sourceEventIndex = 17
      commandId = randomUUID()

      // Generate a hex encoded message from the data
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
        ]
      )

      // Gather EVM signatures from the operators with the hex encoded message
      const signatures = await getWeightedSignatureProof(approveData, operators)

      // Send transaction to execute an approveContractCall command
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
            operator.signingKey.publicKey.slice(4)
          ),
          weights: operators.map(() => 1),
          threshold: operators.length,
          signatures,
        },
        authz: relayer.authz,
      })

      // Expect that a ContractCallApproved event is emitted from the Gateway with the correct data
      expect(tx.events).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            type: `A.${admin.addr.slice(2)}.AxelarGateway.ContractCallApproved`,
            data: expect.objectContaining({
              commandId,
              sourceChain,
              sourceAddress,
              contractAddress,
              payloadHash,
              sourceTxHash,
              sourceEventIndex: sourceEventIndex.toString(),
            }),
          }),
        ])
      )
    })

    it('should call the executable method from the capability that was sent by the dApp', async () => {
      // Send a transaction from the relayer to call the executeApp method
      // for executing the dApp's executable method
      const tx = await executeApp({
        constants,
        args: {
          commandId,
          sourceChain,
          sourceAddress,
          contractAddress,
          payload: Array.from(payload),
        },
        authz: relayer.authz,
      })

      // Validates that an InboxValueClaimed event is emitted since Gateway does not have this capability stored
      // Validates that a CommandApproved event from the ExampleApplication contract is emitted
      // Also Validate that an Executed event from the Gateway is emitted
      expect(tx.events).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            type: 'flow.InboxValueClaimed',
            data: expect.objectContaining({
              provider: dAppUser.addr,
              recipient: admin.addr,
              name: `AppCapabilityPath${dAppUser.addr}`,
            }),
          }),
          expect.objectContaining({
            type: `A.${dAppUser.addr.slice(
              2
            )}.ExampleApplication.CommandApproved`,
            data: expect.objectContaining({
              commandId,
              sourceChain,
              sourceAddress,
            }),
          }),
          expect.objectContaining({
            type: `A.${admin.addr.slice(2)}.AxelarGateway.Executed`,
            data: expect.objectContaining({
              commandId,
            }),
          }),
        ])
      )

      // Gather the approved data from the ExampleApplication
      const approvedData = await getApprovedCommandData({
        args: {
          address: dAppUser.addr,
          commandId,
        },
      })

      // Validates that the data is the same as the data that was sent to the Gateway during approval process
      expect(approvedData).toEqual({
        sourceChain,
        sourceAddress,
        payload: Array.from(payload).map((n) => n.toString()),
      })
    })
  })

  describe('Transfer Operatorship', () => {
    it('should allow operators to transfer operatorship', async () => {
      // Generate new operators, weights, and threshold data
      const newOperators = sortBy(wallets.slice(threshold), (wallet) =>
        wallet.signingKey.publicKey.slice(4)
      ).map((operator) => operator.signingKey.publicKey.slice(4))
      const newWeights = newOperators.map(() => 1 + '')
      const newThreshold = newOperators.length.toString()
      const commandId = randomUUID()

      // Create a hex encoded message from the new operators data
      const approveData = dataToHexEncodedMessage(
        [commandId],
        ['transferOperatorship'],
        [[newOperators, newWeights, newThreshold]]
      )

      // Gather EVM signatures from the current operators
      const signatures = await getWeightedSignatureProof(approveData, operators)

      // Send a transaction to execute the transferOperatorship command
      const tx = await execute({
        constants,
        args: {
          commandIds: [commandId],
          commands: ['transferOperatorship'],
          params: [[newOperators, newWeights, newThreshold]],
          operators: operators.map((operator) =>
            operator.signingKey.publicKey.slice(4)
          ),
          weights: operators.map(() => 1),
          threshold: operators.length,
          signatures,
        },
        authz: relayer.authz,
      })

      // Validate that the OperatorshipTransferred event is emitted
      expect(tx.events).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            type: `A.${admin.addr.slice(
              2
            )}.AxelarAuthWeighted.OperatorshipTransferred`,
            data: expect.objectContaining({
              newOperators,
              newWeights,
              newThreshold,
            }),
          }),
          expect.objectContaining({
            type: `A.${admin.addr.slice(2)}.AxelarGateway.Executed`,
            data: expect.objectContaining({
              commandId,
            }),
          }),
        ])
      )
    })
  })

  describe('Service Contracts', () => {
    const defaultAbiCoder = ethers.AbiCoder.defaultAbiCoder()
    const wallets = Array.from({ length: 10 }).map(() =>
      ethers.Wallet.createRandom()
    )
    const keccak256 = ethers.keccak256
    const encoder = new TextEncoder()
    const user = wallets[0]
    const threshold = 7
    const operators = sortBy(wallets.slice(0, threshold), (wallet) =>
      wallet.signingKey.publicKey.slice(4)
    )
    let constants: FlowConstants
    let dAppUser: FlowAccount
    let relayer: FlowAccount
    let admin: FlowAccount
    let service: FlowAccount

    beforeAll(async () => {
      await Emulator.connect()
    })

    describe('Deploy Core Contracts', () => {
      it('deploy core contracts to admin account', async () => {
        // Create an admin account
        admin = await FlowAccount.from({})

        // Update Flow Constants with admin address
        constants = { ...EMULATOR_CONST, FLOW_ADMIN_ADDRESS: admin.addr }

        // Deploys independent smart contracts to admin account
        const axelarAuthWeightedContract = AxelarAuthWeightedContract()
        await deployAuthContract({
          args: {
            contractName: axelarAuthWeightedContract.name,
            contractCode: axelarAuthWeightedContract.code,
            recentOperators: operators.map((operator) =>
              operator.signingKey.publicKey.slice(4)
            ),
            recentWeights: operators.map(() => 1),
            recentThreshold: operators.length,
          },
          authz: admin.authz,
        })
        // Deploys dependent smart contracts to admin account
        const axelarGatewayContract = AxelarGatewayContract(
          admin.addr,
          utilsAddress
        )
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
        ])
      })
    })
    describe('Onboard Governance Contract With Gateway', () => {
      it('deploy an example application contract to governance account', async () => {
        // Create dApp account
        governanceUser = await FlowAccount.from({})

        // Deploys governance application smart contracts to governance account
        const gatewayAddress = admin.addr
        const governanceServiceContract = AxelarGovernanceServiceContract(
          gatewayAddress
        )
        await deployGovernanceContract({
          args: {
            contractName: governanceServiceContract.name,
            contractCode: governanceServiceContract.code,
            gateway: gatewayAddress,
            governanceChain: 'governanceChain',
            governanceAddress: 'governanceAddress',
            minimumTimeDelay: 0,
          },
          authz: governanceUser.authz,
        })

        // Get the deployed contracts on the dApp account
        const deployedContracts = await getDeployedContracts({
          args: { address: governanceUser.addr },
        })
        expect(deployedContracts).toEqual(['AxelarGovernanceService'])
      })

      it("publishes an AxelarGateway Executable capability to the gateway' inbox", async () => {
        // Publishes the dApp executable capability to Gateway's inbox
        let tx = await publishExecutableCapability({
          constants,
          args: {
            recipient: admin.addr,
          },
          authz: governanceUser.authz,
        })

        // Expect that an InboxValuePublished event is emitted with the correct recipient and provider
        expect(tx.events).toEqual(
          expect.arrayContaining([
            expect.objectContaining({
              type: 'flow.InboxValuePublished',
              data: expect.objectContaining({
                provider: governanceUser.addr,
                recipient: admin.addr,
                name: `AppCapabilityPath${governanceUser.addr}`,
              }),
            }),
          ])
        )
      })
    })

    describe('Setup Auth Capability for Admin Account', () => {
      it('should setup an auth capability for the admin account and send to governance inbox', async () => {
        let tx = await publishAuthCapabilityToGovernance({
          constants,
          args: {
            address: governanceUser.addr,
            recipient: governanceUser.addr,
          },
          authz: admin.authz,
        })

        expect(tx.events).toEqual(
          expect.arrayContaining([
            expect.objectContaining({
              type: 'flow.InboxValuePublished',
              data: expect.objectContaining({
                provider: admin.addr,
                recipient: governanceUser.addr,
                name: `GovernanceUpdaterInbox_${admin.addr}`,
              }),
            }),
            expect.objectContaining({
              type: 'flow.AccountLinked',
              data: expect.objectContaining({
                address: admin.addr,
              }),
            }),
          ])
        )
      })
    })

    describe('Approve Contract Call and Call Executable Method', () => {
      let payload: Uint8Array
      let rawPayload: string
      let sourceChain: string
      let sourceAddress: string
      let contractAddress: string
      let payloadHash: string
      let sourceTxHash: string
      let sourceEventIndex: number
      let commandId: string

      it('should approve a contract call', async () => {
        // Create a relayer account for relaying messages with transactions
        relayer = await FlowAccount.from({})

        const updatedCode = AxelarGatewayUpdateContract(
          admin.addr,
          utilsAddress
        )

        await fs.writeFileSync(
          'tests/utils/updated-contracts/AxelarGateway-updated.cdc',
          updatedCode.code
        )

        const execPromise = util.promisify(exec)
        const { stdout, stderr } = await execPromise(
          `python3 tests/utils/get_code_hex.py tests/utils/updated-contracts/AxelarGateway-updated.cdc`
        )
        rawPayload = stdout.slice(0, -1)
        payload = encoder.encode(rawPayload)
        sourceChain = 'governanceChain'
        sourceAddress = 'governanceAddress'
        contractAddress = governanceUser.addr
        payloadHash = keccak256(payload)
        sourceTxHash = keccak256('0x123abc123abc')
        sourceEventIndex = 17
        commandId = randomUUID()

        // Generate a hex encoded message from the data
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
          ]
        )

        // Gather EVM signatures from the operators with the hex encoded message
        const signatures = await getWeightedSignatureProof(
          approveData,
          operators
        )

        // Send transaction to execute an approveContractCall command
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
              operator.signingKey.publicKey.slice(4)
            ),
            weights: operators.map(() => 1),
            threshold: operators.length,
            signatures,
          },
          authz: relayer.authz,
        })

        // Expect that a ContractCallApproved event is emitted from the Gateway with the correct data
        expect(tx.events).toEqual(
          expect.arrayContaining([
            expect.objectContaining({
              type: `A.${admin.addr.slice(
                2
              )}.AxelarGateway.ContractCallApproved`,
              data: expect.objectContaining({
                commandId,
                sourceChain,
                sourceAddress,
                contractAddress,
                payloadHash,
                sourceTxHash,
                sourceEventIndex: sourceEventIndex.toString(),
              }),
            }),
          ])
        )
      })

      it('should call the executable method from the capability that was sent by the dApp', async () => {
        // Send a transaction from the relayer to call the executeApp method
        // for executing the dApp's executable method
        const tx = await executeApp({
          constants,
          args: {
            commandId,
            sourceChain,
            sourceAddress,
            contractAddress,
            payload: Array.from(payload),
          },
          authz: relayer.authz,
        })

        // Validates that an InboxValueClaimed event is emitted since Gateway does not have this capability stored
        // Validates that a CommandApproved event from the ExampleApplication contract is emitted
        // Also Validate that an Executed event from the Gateway is emitted
        expect(tx.events).toEqual(
          expect.arrayContaining([
            expect.objectContaining({
              type: 'flow.InboxValueClaimed',
              data: expect.objectContaining({
                provider: governanceUser.addr,
                recipient: admin.addr,
                name: `AppCapabilityPath${governanceUser.addr}`,
              }),
            }),
            expect.objectContaining({
              type: `A.${governanceUser.addr.slice(
                2
              )}.AxelarGovernanceService.ProposalScheduled`,
              // data: expect.objectContaining({
              //   commandId,
              //   sourceChain,
              //   sourceAddress,
              // }),
            }),
            expect.objectContaining({
              type: `A.${admin.addr.slice(2)}.AxelarGateway.Executed`,
              data: expect.objectContaining({
                commandId,
              }),
            }),
          ])
        )
        const eta = await getProposalEta({
          args: {
            address: governanceUser.addr,
            target: admin.addr,
            proposedCode: rawPayload,
          },
        })

        expect(eta).not.toEqual(0)
      })

      it('execute scheduled proposal', async () => {
        await executeGovernanceProposal({
          constants,
          args: {
            address: governanceUser.addr,
            target: admin.addr,
            proposedCode: rawPayload,
          },
          authz: relayer.authz,
        })

        await getContractCode({
          args: {
            address: admin.addr,
            name: 'AxelarGateway',
          },
        })
      })
    })
  })
})
