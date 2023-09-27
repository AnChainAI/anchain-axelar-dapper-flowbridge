#!/usr/bin/env bash

# NOTE: Before running this script, make sure your emulator
# is online by running the following command: flow emulator

# https://stackoverflow.com/questions/821396/aborting-a-shell-script-if-any-command-returns-a-non-zero-value
set -e

# Helps make output more readable
BLUE=$(tput setaf 4)
NORMAL=$(tput sgr0)

# Ensures that this script is run from the same directory as flow.json
cd "$(dirname "$0")"
cd ../

# Create an account for development purposes
printf "\n${BLUE}Creating a FLOW account for development purposes...\n\n${NORMAL}"
flow accounts create \
  --key d8eaaeaefe1dc4569904c8a23f44841a36895b445c5110abd649378eb9a5cf9b2fac31578490fd4b4920484afda294ff5d41bb12ef9dc665888edb9503adea12 \
  --key-weight 1000 \
  --signer emulator-account \
  --hash-algo SHA3_256 \
  --sig-algo ECDSA_P256

# NOTE: The Flow emulator is deterministic. The first account 
# we create on startup will always have address 0x01cf0e2f2f715450
ADDR=0x01cf0e2f2f715450

# Fund the account with FLOW tokens
printf "\n\n${BLUE}Sending FLOW tokens to newly created account...\n\n${NORMAL}"
flow transactions send ./cadence/transactions/flow-tokens/mint.cdc $ADDR 1000.0

# Deploy core contracts to emulator
printf "\n\n${BLUE}Deploying contracts...\n${NORMAL}"
flow project deploy

# Notify user that setup is done
printf "${BLUE}Setup complete!\n${NORMAL}"
 