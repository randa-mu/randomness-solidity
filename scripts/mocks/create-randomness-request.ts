import { JsonRpcProvider, ethers, AbiCoder, getBytes, AddressLike } from "ethers";
import 'dotenv/config'
import {
    SignatureSender__factory,
    RandomnessSender__factory,
    MockRandomnessReceiver__factory,
} from "../../typechain-types";

// Usage:
// yarn ts-node scripts/mocks/create-randomness-request.ts 

const RPC_URL = process.env.CALIBRATIONNET_RPC_URL;

const walletAddr = "0x5d84b82b750B996BFC1FA7985D90Ae8Fbe773364"
const randomnessSenderAddr = "0x9c789bc7F2B5c6619Be1572A39F2C3d6f33001dC"
const signatureSenderAddr = "0x1c86A81D3CDD897aFdcA62a9b7219a39Aef7910B";
const mockRandomnessReceiverAddr = "0x6e7B9Ccb146f6547172E5cef237BBc222EC4D676";

// Create a provider using the RPC URL
const provider = new ethers.JsonRpcProvider(RPC_URL);

// Create a signer using the private key
const signer = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

async function getWalletBalance(walletAddress: string): Promise<void> {
    try {
        // Get the wallet balance
        const balance = await provider.getBalance(walletAddress);

        // Convert the balance from Wei to Ether and print it
        console.log(`Balance of ${walletAddress}: ${ethers.formatEther(balance)} ETH`);
    } catch (error) {
        console.error("Error fetching wallet balance:", error);
    }
}

async function latestBlockNumber(provider: JsonRpcProvider) {
    // Fetch the latest block number
    const latestBlockNumber = await provider.getBlockNumber();
    console.log(`Latest Block Number: ${latestBlockNumber}`);
    return latestBlockNumber;
}

async function createRandomnessRequest() {
    // Create randomnessSender instance with proxy contract address
    const randomnessSender = new ethers.Contract(randomnessSenderAddr, RandomnessSender__factory.abi, provider);
    // cast call 0x9c789bc7F2B5c6619Be1572A39F2C3d6f33001dC "version()(string)" --rpc-url https://rpc.ankr.com/filecoin_testnet
    console.log("SignatureSender address from randomnessSender proxy", await randomnessSender.signatureSender());

    // Create signatureSender instance with proxy contract address
    const signatureSender = new ethers.Contract(signatureSenderAddr, SignatureSender__factory.abi, provider);
    console.log("Version number from signatureSender proxy", await signatureSender.version());

    // Create mockRandomnessReceiver instance with implementation contract address
    const mockRandomnessReceiver = MockRandomnessReceiver__factory.connect(mockRandomnessReceiverAddr, signer);
    console.log("randomnessSender addr from mockRandomnessReceiver", await mockRandomnessReceiver.randomnessSender());
    console.log("Current randomness value from mockRandomnessReceiver", await mockRandomnessReceiver.randomness());
    console.log("Current requestId value from mockRandomnessReceiver", await mockRandomnessReceiver.requestId());
    console.log("is the current request id in flight?", await signatureSender.isInFlight(await mockRandomnessReceiver.requestId()));

    // create a randomness request from mockRandomnessReceiver contract and check it is fulfilled by randomness agent
    // call rollDice() in mockRandomnessReceiver
    let tx = await mockRandomnessReceiver.connect(signer).rollDice();
    let receipt = await tx.wait(1);
    if (!receipt) {
        throw new Error("transaction has not been mined");
    }
    const reqId = await mockRandomnessReceiver.requestId();
    console.log("Created request id on filecoin testnet:", reqId);
    
    console.log("Request creation block height:", await provider.getBlockNumber())
    console.log("is created randomness request id inFlight?:", await signatureSender.isInFlight(reqId));

}

async function replacePendingTransaction() {
    let txData = {
        to: "0x5d84b82b750B996BFC1FA7985D90Ae8Fbe773364",
        value: "0", 
        chainId: 314159,
        nonce: 1420,
        gasLimit: 10000000000,
        gasPrice: 2000000000
    }
    let estimate = await provider.estimateGas(txData)
    txData.gasLimit = Number(estimate);
    txData.gasPrice = Number(ethers.parseUnits("0.14085197", "gwei"));
    let tx = await signer.sendTransaction(txData)
    let receipt = await tx.wait(1)
    console.log(receipt)
}

async function getTransactionCount(walletAddr: AddressLike) {
    const txCount = await provider.getTransactionCount(walletAddr);
    console.log(`Transaction count for ${walletAddr} is ${txCount}`);
    return txCount;
}

async function main() {
    const walletAddr = await signer.getAddress()

    try {
        // Get latest block number
        await latestBlockNumber(provider);

        // Get wallet ETH balance
        await getWalletBalance(walletAddr);

        // get signer wallet trasaction count
        await getTransactionCount(walletAddr);

        // create a new randomness request
        await createRandomnessRequest();
    } catch (error) {
        console.error("Error fetching latest block number:", error);
    }
}

main()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error(err);
        process.exit(1);
    });