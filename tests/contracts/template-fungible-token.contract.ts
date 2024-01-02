import { readFileSync } from "fs"
import { ContractDetails, FlowConstants } from "../../utils/flow"
import { findFilePath } from "../../utils/testing"
import { join } from 'path'

export const TemplateFungibleToken = (
    constants: FlowConstants,
    address: string,
  ): ContractDetails => {
    return {
      name: 'AxelarFungibleToken',
      code: readFileSync(findFilePath(join('contract-templates', 'AxelarFungibleToken.cdc')), 'utf8')
      .replace('"FungibleToken"', constants.FLOW_FT_ADDRESS)
      .replace('"MetadataViews"', address)
      .replace('"FungibleTokenMetadataViews"', address)
      .replace('"AxelarFungibleTokenInterface"', address),
    }
  }