import { readFileSync } from "fs"
import { ContractDetails, FlowConstants } from "../../utils/flow"
import { findFilePath } from "../../utils/testing"
import { join } from 'path'

export const TemplateViewResolver = (
    constants: FlowConstants,
  ): ContractDetails => {
    return {
      name: 'ViewResolver',
      code: readFileSync(findFilePath(join('standard', 'ViewResolver.cdc')), 'utf8')
    }
  }