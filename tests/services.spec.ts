import { exec } from 'child_process'
import { randomUUID } from 'crypto'
import fs from 'fs'
import { ethers } from 'hardhat'
import { sortBy, template } from 'lodash'
import util from 'util'
import { FlowConstants } from '../utils/flow'
import { EMULATOR_CONST, Emulator, FlowAccount } from '../utils/testing'
import { AxelarAuthWeightedContract } from './contracts/axelar-auth-weighted.contract'
import { AxelarGasServiceContract } from './contracts/axelar-gas-service.contract'
import { AxelarGatewayUpdateContract } from './contracts/axelar-gateway-updated.contract'
import { AxelarGatewayContract } from './contracts/axelar-gateway.contract'
import { AxelarGovernanceServiceContract } from './contracts/axelar-governance-service.contract'
import { ExampleApplicationContract } from './contracts/example-application.contract'
import { getContractCode } from './scripts/get-contract-code'
import { getDeployedContracts } from './scripts/get-deployed-contracts'
import { getApprovedCommandData } from './scripts/get-example-app-data'
import { getProposalEta } from './scripts/get-proposal-eta'
import { callContract } from './transactions/call-contract'
import { deployAuthContract } from './transactions/deploy-auth-contract'
import { deployContracts } from './transactions/deploy-contracts'
import { deployGovernanceContract } from './transactions/deploy-governance-contract'
import { execute } from './transactions/execute'
import { executeApp } from './transactions/execute-app'
import { executeGovernanceProposal } from './transactions/execute-governance-proposal'
import { gasServiceAdd } from './transactions/gas-service-add'
import { gasServicePay } from './transactions/gas-service-pay'
import { publishAuthCapabilityToGovernance } from './transactions/publish-auth-capability'
import { publishExecutableCapability } from './transactions/publish-executable-capability'
import { setupFlowAccount } from './transactions/setup-flow-token-account'
import { dataToHexEncodedMessage } from './utils/data-to-hex-encoded-message'
import { getWeightedSignatureProof } from './utils/get-weighted-signatures-proof'
import { TemplateFungibleToken } from './contracts/template-fungible-token.contract'
import { TemplateMetadataViews } from './contracts/template-metadata-views.contract'
import { TemplateFungibleTokenMetadataViews } from './contracts/template-fungible-token-metadata-views'
import { deployTokenTemplate } from './transactions/deploy-example-token-contract'
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
describe('Service Contracts', () => {
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
  let userAccount: FlowAccount

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
          recentOperatorsSet: [
            operators.map((operator) => operator.signingKey.publicKey.slice(4)),
          ],
          recentWeightsSet: [operators.map(() => 1)],
          recentThresholdSet: [operators.length],
        },
        authz: admin.authz,
      })
      // Deploys dependent smart contracts to admin account
      const axelarGatewayContract = AxelarGatewayContract(
        admin.addr,
        utilsAddress,
        constants
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
  describe('Onboard Governance Contract With Gateway', () => {
    it('deploy an example application contract to governance account', async () => {
      // Create dApp account
      governanceUser = await FlowAccount.from({})
      userAccount = await FlowAccount.from({})

      // Deploys governance application smart contracts to governance account
      const gatewayAddress = admin.addr
      const governanceServiceContract = AxelarGovernanceServiceContract(
        gatewayAddress,
        constants
      )
      const gasServiceContract = AxelarGasServiceContract(
        constants.FLOW_TOKEN_ADDRESS,
        constants.FLOW_FT_ADDRESS
      )
      //Deploy Gas Service Contract to Governance Account
      await deployContracts({
        args: {
          contracts: [gasServiceContract],
        },
        authz: governanceUser.authz,
      })

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
      expect(deployedContracts).toEqual([
        'AxelarGasService',
        'AxelarGovernanceService',
      ])
    })

    it('setup Flow Token Account on Governance and User Account', async () => {
      await setupFlowAccount({
        constants,
        args: {},
        authz: governanceUser.authz,
      })
      await setupFlowAccount({
        constants,
        args: {},
        authz: userAccount.authz,
      })
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

      const updatedCode = AxelarGatewayUpdateContract(admin.addr, utilsAddress)

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
              provider: governanceUser.addr,
              recipient: admin.addr,
              name: `AppCapabilityPath${governanceUser.addr}`,
            }),
          }),
          expect.objectContaining({
            type: `A.${governanceUser.addr.slice(
              2
            )}.AxelarGovernanceService.ProposalScheduled`,
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
  describe('Gas Service', () => {
    it('creates gas payment', async () => {
      let isExpress = false
      let destinationChain = 'destinationChain'
      let destinationAddress = 'destinationAddress'
      let payloadHash = [1, 2, 3]
      let gasFeeAmount = '100.0'
      let refundAddress = userAccount.addr

      let tx = await gasServicePay({
        constants,
        args: {
          gasAddress: governanceUser.addr,
          isExpress: isExpress,
          destinationChain: destinationChain,
          destinationAddress: destinationAddress,
          payloadHash: payloadHash,
          gasFeeAmount: gasFeeAmount,
          refundAddress: refundAddress,
        },
        authz: userAccount.authz,
      })
      console.log(tx.events)
      expect(tx.events).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            type: `A.${governanceUser.addr.slice(
              2
            )}.AxelarGasService.NativeGasPaidForContractCall`,
            data: expect.objectContaining({
              sourceAddress: userAccount.addr,
              destinationChain: destinationChain,
              destinationAddress: destinationAddress,
              refundAddress: refundAddress,
            }),
          }),
        ])
      )
    })

    it('adds gas payment to existing txn', async () => {
      let isExpress = false
      let txHash = '0x123abc'
      let logIndex = 1
      let gasFeeAmount = '100.0'
      let refundAddress = userAccount.addr

      let tx = await gasServiceAdd({
        constants,
        args: {
          gasAddress: governanceUser.addr,
          isExpress: isExpress,
          txHash: txHash,
          logIndex: logIndex,
          gasFeeAmount: gasFeeAmount,
          refundAddress: refundAddress,
        },
        authz: userAccount.authz,
      })
      console.log(tx.events)
      expect(tx.events).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            type: `A.${governanceUser.addr.slice(
              2
            )}.AxelarGasService.NativeGasAdded`,
            data: expect.objectContaining({
              txHash: txHash,
              refundAddress: refundAddress,
            }),
          }),
        ])
      )
    })
  })
  describe('Interchain Token Service', () => {
    it('deploy template fungible token contract', async () => {

      const templateFungibleToken = TemplateFungibleToken(
        constants,
        admin.addr 
      )
      const templateFungibleTokenMetadataViews = TemplateFungibleTokenMetadataViews(
        constants,
        admin.addr
      )
      const templateMetadataViews = TemplateMetadataViews(
        constants
      )
      await deployContracts({
        args: {
          contracts: [templateMetadataViews],
        },
        authz: admin.authz,
      })

      await deployContracts({
        args: {
          contracts: [templateFungibleTokenMetadataViews],
        },
        authz: admin.authz,
      })

      await deployTokenTemplate({
        args: {
          contractName: templateFungibleToken.name,
          contractCode: templateFungibleToken.code,
        },
        authz: admin.authz,
      })

    })
    it('deploy interchain token service to gateway account', async () => {

    })
  })
})
