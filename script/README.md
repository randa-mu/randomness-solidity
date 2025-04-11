# Contract Deployment

The deployment [scripts](script) enable the deployment of single contracts or all contracts in a single run.

## Environment setup

Create a `.env` file. Then copy the `.env.example` to the `.env` file and set the applicable configuration variables for the testing / deployment environment.

Deployment is handled by solidity scripts in forge. The network being deployed to is dependent on the `RPC_URL` environment variable.

## Deploy the CREATE2 Factory Contract

If deploying to a network that does not support the [deterministic deployer contract used by Foundry](https://book.getfoundry.sh/guides/deterministic-deployments-using-create2), deploy the [CREATE2 Factory.sol](src/Factory.sol) contract and set the `CREATE2_FACTORY` address in the [Constants.sol library](script/libraries/Constants.sol) for use within the deployment scripts. 

Note: The wallet address linked to the deployer private key is used as the `ADMIN` address in the core contracts and fetched using the [EnvReader](script/utils/EnvReader.sol).


```sh
source .env

# Deploy CREATE2 Factory
forge script script/DeployFactory.s.sol:DeployFactory --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --slow
```

For Filecoin Calibration Testnet, a common [deployment issue](https://github.com/filecoin-project/fevm-foundry-kit) that you may see is a failure due to gas. Simply pass in a higher gas limit to fix this (either via. a higher gas estimate multiplier using the `-g` flag or a fixed gas limit) e.g.,

```sh
forge script script/DeployFactory.s.sol:DeployFactory --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --slow -g 10000
```

## Deploy All Contracts

To deploy all contracts in a single run, the `DeployAllContracts` script is used. This will run the deployments for all contracts specified in the script.
```sh
source .env

forge script script/DeployAllContracts.s.sol:DeployAllContracts --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --slow
```

For Etherscan verification, ensure that the `ETHERSCAN_API_KEY` environment variable is set and add the `--verify` flag to the forge script deployment commands.

## Deploy a Single Contract

To deploy a single contract, the scripts within the `script/single-deployment` directory are used, e.g., to deploy only the `MockBN254SignatureScheme.sol` contract contract, the command below is used:

```sh
source .env

forge script script/single-deployment/DeployBN254SignatureScheme.s.sol:DeployBN254SignatureScheme --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --slow
```

To resolve dependencies between the contract deployments, a `.json` file named [Deployment_input.json](script/json/Deployment_input.json) in the [script](script) folder is filled with contract addresses for the following contracts after they are deployed (either as single deployments or part of the single run deployment for all contracts):
* RandomnessSender (proxy address)
* SignatureSender (proxy address)
* SignatureSchemeAddressProvider

The addresses from this input file are read in by scripts using them. To overwrite the addresses in this file, replace them with the relevant address for each contract.

For example, running the following command writes a JSON property `{"signatureSchemeAddressProviderAddress": "0x7D020A4E3D8795581Ec06E0e57701dDCf7B19EDF"}` to the Deployment_input.json file:

```bash
forge script script/single-deployment/DeploySignatureSchemeAddressProvider.s.sol:DeploySignatureSchemeAddressProvider --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --slow
```

Which is used by the [DeployBN254SignatureScheme.sol](script/single-deployment/DeployBN254SignatureScheme.s.sol) deployment script when deploying [MockBN254SignatureScheme.sol](src/mocks/MockBN254SignatureScheme.sol).


## Upgrade a Single Contract

To upgrade the implementation contract for any of the `Sender` contracts, set the `IS_UPGRADE` to `true` in the `.env` file. Then in [Constants.sol](script/libraries/Constants.sol), set the `SALT` for deployment. After setting the salt, run the deployment command only for the specific contract to upgrade, e.g., if upgrading `SignatureSender` implementation, run the following command for a single contract deployment:

```bash
forge script script/single-deployment/DeploySignatureSender.s.sol:DeploySignatureSender --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --slow
```


## Deployment addresses

The file `contract-addresses.json` lists all official deployments of the contracts in this repository by `chain id`.

The deployment addresses file is generated with:

```sh
bash utils/generate-contract-addresses.sh > contract-addresses.json
```