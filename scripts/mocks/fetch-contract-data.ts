import { JsonRpcProvider, ethers, AbiCoder, getBytes } from "ethers";
import 'dotenv/config'
import {
    SignatureSender__factory,
    RandomnessSender__factory,
    MockRandomnessReceiver__factory,
} from "../../typechain-types";

// Usage:
// yarn ts-node scripts/mocks/fetch-contract-data.ts 

const RPC_URL = process.env.CALIBRATIONNET_RPC_URL;

const walletAddr = "0x5d84b82b750B996BFC1FA7985D90Ae8Fbe773364"
const randomnessSenderAddr = "0x9c789bc7F2B5c6619Be1572A39F2C3d6f33001dC"
const signatureSenderAddr = "0x1c86A81D3CDD897aFdcA62a9b7219a39Aef7910B";
const mockRandomnessReceiverAddr = "0x6e7B9Ccb146f6547172E5cef237BBc222EC4D676";

async function getWalletBalance(rpcUrl: string, walletAddress: string): Promise<void> {
    try {
        // Connect to the Ethereum network using the RPC URL
        const provider = new ethers.JsonRpcProvider(rpcUrl);

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
}

async function main() {
    try {
        // Create a provider using the RPC URL
        const provider = new ethers.JsonRpcProvider(RPC_URL);

        // Create a signer using the private key
        const signer = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

        // Get latest block number
        await latestBlockNumber(provider);

        // Get wallet ETH balance
        await getWalletBalance(RPC_URL!, walletAddr);

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

        console.log(await randomnessSender.getRequest(2))
        console.log("\n", await signatureSender.getRequest(2))

        const erroredRequestIds = await signatureSender.getAllErroredRequestIds()
        console.log(`Errored request ids ${erroredRequestIds}`)

        const unfilfilledRequestIds = await signatureSender.getAllUnfulfilledRequestIds()
        console.log(`Unfulfilled request ids ${unfilfilledRequestIds}`)

        const fulfilledRequestIds = await signatureSender.getAllFulfilledRequestIds()
        console.log(`Unfulfilled request ids ${fulfilledRequestIds}`)
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