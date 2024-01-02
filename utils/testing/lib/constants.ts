import { FlowConstants } from '../../flow'

export const EMULATOR_CONST: Omit<FlowConstants, 'FLOW_ADMIN_ADDRESS'> = {
  FLOW_ACCESS_API: 'http://localhost:8080',
  FLOW_TOKEN_ADDRESS: '0x0ae53cb6e3f42a79',
  FLOW_FT_ADDRESS: '0xee82856bf20e2aa6',
  FLOW_NFT_ADDRESS:'0xf8d6e0586b0a20c7'
}
