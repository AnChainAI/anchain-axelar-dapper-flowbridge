import { sendTransaction, TransactionFunctionParams } from '../../utils/flow';

const changeAccountCreationFeeCode = (contractAddress: string) => `
  import InterchainTokenService from ${contractAddress}

  transaction(newAccountCreationFee: UFix64) {
    prepare(signer: AuthAccount) {
      InterchainTokenService.changeAccountCreationFee(newFee: newAccountCreationFee)
    }
    execute {
      log("Account creation fee changed successfully")
    }
  }
`;

export interface ChangeAccountCreationFeeArgs {
  readonly contractAddress: string;
  readonly newAccountCreationFee: number;
}

export async function changeAccountCreationFee(
  params: TransactionFunctionParams<ChangeAccountCreationFeeArgs>
) {
  return await sendTransaction({
    cadence: changeAccountCreationFeeCode(params.args.contractAddress),
    args: (arg, t) => [
      arg(params.args.newAccountCreationFee, t.UFix64),
    ],
    authorizations: [params.authz],
    payer: params.authz,
    proposer: params.authz,
    limit: 9999,
  });
}
