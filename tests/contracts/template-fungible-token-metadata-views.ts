import { readFileSync } from "fs"
import { ContractDetails, FlowConstants } from "../../utils/flow"
import { findFilePath } from "../../utils/testing"
import { join } from 'path'

export const TemplateFungibleTokenMetadataViews = (
    constants: FlowConstants,
    address: string,
  ): ContractDetails => {
    return {
      name: 'FungibleTokenMetadataViews',
      code: readFileSync(findFilePath(join('contract-templates', 'FungibleTokenMetadataViews.cdc')), 'utf8')
      .replace('"FungibleToken"', constants.FLOW_FT_ADDRESS)
      .replace('"MetadataViews"', address),
    }
  }