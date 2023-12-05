# Interchain Token Service (ITS)

The interchain token service is an Axelar Executable which handles the processing and launching of cross chain tokens which are supported by the Axelar Network

## Basic Functionalities

- ### Token Launching

  - Tokens which are native on other chains in the Axelar Network should be able to be launched on flow as 'Fungible Tokens'.  These are known as 'Axelar Wrapped' tokens.
- ### Distributing Cross Chain Canonical Tokens

  - When a Interchain token transfer call is received, the ITS should issue the correct amount of funds from the defined token contract.  These token distributions will follow a mint/burn pattern as to match the liquidity locked up in other ITS implementations.
- ### Collecting Native Tokens

  - The ITS will collect flow native tokens and store them in a vault.  These tokens will be locked up as they will be distributed on other chains in the Axelar Ecosystem.
