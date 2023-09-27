import { Emulator, FlowAccount } from '../utils/testing'

// npm test -- gateway.spec.ts
describe('AxelarGateway', () => {
  let admin: FlowAccount

  beforeAll(async () => {
    await Emulator.connect()

    admin = await FlowAccount.from({})
  })

  it('test emulator connection and flow account creation', async () => {
    const address = admin.addr
    console.log(address)
  })
})
