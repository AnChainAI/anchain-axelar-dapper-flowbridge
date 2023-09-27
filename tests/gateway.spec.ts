import { Emulator, FlowAccount } from '../util-testing'

// npm test -- gateway.spec.ts
describe('test', () => {
  let admin: FlowAccount

  beforeAll(async () => {
    await Emulator.connect()

    admin = await FlowAccount.from({})
  })

  it('hello world', async () => {
    const address = admin.addr
    console.log(address)
  })
})
