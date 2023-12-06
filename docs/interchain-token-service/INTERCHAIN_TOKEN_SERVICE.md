# Interchain Token Service (ITS)

The interchain token service is an Axelar Executable which handles the processing and launching of cross chain tokens which are supported by the Axelar Network

### Basic Functionalities

- ### Token Launching

  - Tokens which are native on other chains in the Axelar Network should be able to be launched on flow as 'Fungible Tokens'.  These are known as 'Axelar Wrapped' tokens.
- ### Distributing Cross Chain Canonical Tokens

  - When a Interchain token transfer call is received, the ITS should issue the correct amount of funds from the defined token contract.  These token distributions will follow a mint/burn pattern as to match the liquidity locked up in other ITS implementations.
- ### Collecting Native Tokens

  - The ITS will collect flow native tokens and store them in a vault.  These tokens will be locked up as they will be distributed on other chains in the Axelar Ecosystem.

## Implementation Plan

- ### Token Launching

  - Since contract launching and account management is significantly different from Flow and EVM we will opt for a prelaunch and link method.
  - Steps will look something like the following:

    1. A interchain command is received which requests the token to be launched on Flow
    2. The ITS will create a new account with the same key that is used by the ITS
    3. The ITS will then launch a new 'InterchainFungibleToken' contract from a deployed template contract
    4. The ITS will also deploy a FungibleMetadata contract to the account and provide all metadata as initialization variables.
    5. The new account is then linked as a child account to the ITS via the Auth Account Capability.  The AuthAccount Capability will be sent to the ITS's capability inbox
    6. The ITS will receive a link or token launch command in which it will claim the previously sent capability from its inbox.  This Auth Account Capability will be stored under a storage path such as `/storage/accounts/0xADDRESS`
    7. The ITS will then create a InterchainToken object which will store a reference to this AuthAccount Capability as well as the Administrator, Minter, and Burner Capability from the child accounts Fungible Token
- # Distributing Cross Chain Canonical Tokens

  - Steps:
    1. ITS receives a InterchainTransfer for a non native flow token that has already been launched by the system defined above.
    2. The ITS will then set a pre approval for the defined destination address and token
    3. The user will have to come and retrieve said tokens by passing in a vault and calling a 'claim' function.  This will ensure the user has the ability to setup their token vault and ensure the account can receive tokens
    4. User claims tokens and approval is destroyed
- ### Collecting Native Tokens

  - Steps:
    1. The user will initiate a InterchainTransfer call which passes in a vault with the desired token as well as the address and name of said token.  A payload is also passed in to initiate a contract call after the funds have been locked
    2. The ITS will store said tokens in the vault specified the token
    3. a interchain transfer event will be omitted
    4. The gateway's callContract is then called and the payload is passed through
