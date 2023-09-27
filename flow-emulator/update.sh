set -e

# https://developers.flow.com/tools/flow-cli/install
if [ "$#" -eq 1 ]; then
  sh -ci "$(curl -fsSL https://raw.githubusercontent.com/onflow/flow-cli/master/install.sh)" -- $1
else
  sh -ci "$(curl -fsSL https://raw.githubusercontent.com/onflow/flow-cli/master/install.sh)"
fi
