import FungibleToken from "FungibleToken"
import MetadataViews from "MetadataViews"
// import "MetadataViews"
import FungibleTokenMetadataViews from "FungibleTokenMetadataViews"

pub contract interface AxelarFungibleTokenInterface{

    /// Total supply of AxelarFungibleTokens in existence
    pub var totalSupply: UFix64

    /// Storage and Public Paths
    pub let VaultStoragePath: StoragePath
    pub let VaultPublicPath: PublicPath
    pub let ReceiverPublicPath: PublicPath
    pub let AdminStoragePath: StoragePath

    /// The event that is emitted when the contract is created
    pub event TokensInitialized(initialSupply: UFix64)

    /// The event that is emitted when tokens are withdrawn from a Vault
    pub event TokensWithdrawn(amount: UFix64, from: Address?)

    /// The event that is emitted when tokens are deposited to a Vault
    pub event TokensDeposited(amount: UFix64, to: Address?)

    /// The event that is emitted when new tokens are minted
    pub event TokensMinted(amount: UFix64)

    /// The event that is emitted when tokens are destroyed
    pub event TokensBurned(amount: UFix64)

    /// The event that is emitted when a new minter resource is created
    pub event MinterCreated()

    /// The event that is emitted when a new burner resource is created
    pub event BurnerCreated()

    pub let name: String
    pub let symbol: String

    pub resource interface AdministratorInterface {
        pub fun createNewMinter(): @Minter
        pub fun createNewBurner(): @Burner
    }

    pub resource interface MinterInterface {
        pub fun mintTokens(amount: UFix64): @FungibleToken.Vault?
    }

    pub resource interface BurnerInterface {
        pub fun burnTokens(from: @FungibleToken.Vault)
    }

    pub resource Administrator: AdministratorInterface {

        /// Function that creates and returns a new minter resource
        ///
        /// @param allowedAmount: The maximum quantity of tokens that the minter could create
        /// @return The Minter resource that would allow to mint tokens
        ///
        pub fun createNewMinter(): @Minter

        /// Function that creates and returns a new burner resource
        ///
        /// @return The Burner resource
        ///
        pub fun createNewBurner(): @Burner
    }

    access(account) fun getAdminCapability(): @Administrator

    /// Resource object that token admin accounts can hold to mint new tokens.
    ///
    pub resource Minter {

        pub fun mintTokens(amount: UFix64): @FungibleToken.Vault?
    }

    /// Resource object that token admin accounts can hold to burn tokens.
    ///
    pub resource Burner {

        /// Function that destroys a Vault instance, effectively burning the tokens.
        ///
        /// Note: the burned tokens are automatically subtracted from the
        /// total supply in the Vault destructor.
        ///
        /// @param from: The Vault resource containing the tokens to burn
        ///
        pub fun burnTokens(from: @FungibleToken.Vault)
    }

    init(tokenName: String, symbol: String)
}