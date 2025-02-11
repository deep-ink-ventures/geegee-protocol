const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {

    // Ensure the directory exists
    const deploymentsDir = path.join(__dirname, `../deployments`);
    if (!fs.existsSync(deploymentsDir)) {
        throw new Error("Deployments directory does not exist");
    }

    // Get the network name
    const networkName = hre.network.name;
    console.log(`Deploying to network: ${networkName}`);

    const PickAWinnerFactory = await hre.ethers.getContractFactory("PickAWinnerFactory");
    const factory = await PickAWinnerFactory.deploy();

    const address = await factory.getAddress();
    console.log(`PickAWinnerFactory deployed at: ${address}`);

    if (networkName !== "localhost") {
        const filePath = path.join(deploymentsDir, `${networkName}.txt`);
        fs.writeFileSync(filePath, address, "utf8");
        console.log(`Contract address saved to ${filePath}`);
    }
}

// Run the script with error handling
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
