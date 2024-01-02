import { readFileSync } from "fs"
import { ContractDetails, FlowConstants } from "../../utils/flow"
import { findFilePath } from "../../utils/testing"
import { join } from 'path'

export const TemplateFungibleTokenInterface = (
    constants: FlowConstants,
    address: string,
  ): ContractDetails => {
    return {
      name: 'AxelarFungibleTokenInterface',
      code: readFileSync(findFilePath(join('contract-templates', 'AxelarFungibleTokenInterface.cdc')), 'utf8')
      .replace('"FungibleToken"', constants.FLOW_FT_ADDRESS)
      .replace('"MetadataViews"', address)
      .replace('"FungibleTokenMetadataViews"', address),
    }
  }