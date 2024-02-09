import { readFileSync } from "fs"
import { ContractDetails, FlowConstants } from "../../utils/flow"
import { findFilePath } from "../../utils/testing"
import { join } from 'path'

export const TemplateMetadataViews = (
    constants: FlowConstants,
  ): ContractDetails => {
    return {
      name: 'MetadataViews',
      code: readFileSync(findFilePath(join('contract-templates', 'MetadataViews.cdc')), 'utf8')
      .replace('"FungibleToken"', constants.FLOW_FT_ADDRESS)
      .replace('"NonFungibleToken"', constants.FLOW_NFT_ADDRESS),
    }
  }