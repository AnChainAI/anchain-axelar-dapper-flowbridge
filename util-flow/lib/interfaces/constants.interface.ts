export interface FlowConstants {
  /**
   * The Flow access API.
   */
  readonly FLOW_ACCESS_API: string

  /**
   * The address of the admin account that has the OpenSale smart contract.
   */
  readonly FLOW_ADMIN_ADDRESS: string

  /**
   * The address of the account that has the FlowToken smart contract.
   */
  readonly FLOW_TOKEN_ADDRESS: string

  /**
   * The address of the account that has the FungibleToken smart contract.
   */
  readonly FLOW_FT_ADDRESS: string

  /**
   * The address of the account that has the NonFungibleToken smart contract.
   */
  readonly FLOW_NFT_ADDRESS: string

  /**
   * The address of the account that has the NFTStorefront smart contract.
   */
  readonly FLOW_NFT_STOREFRONT_ADDRESS: string

  /**
   * The address of the account that has the MetadataViews smart contract.
   */
  readonly FLOW_METADATA_VIEWS_ADDRESS: string

  /**
   * The address of the account that has the RoleV1 smart contract.
   */
  readonly FLOW_ROLE_V1_ADDRESS: string

  /**
   * The address of the account that has the VerifyV1 smart contract.
   */
  readonly FLOW_VERIFY_V1_ADDRESS: string

  /**
   * The address of the account that has the AccessControlV1 smart contract.
   */
  readonly FLOW_ACCESS_CONTROL_V1_ADDRESS: string
}
