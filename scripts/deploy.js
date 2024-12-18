const hre = require("hardhat");

async function main() {
    console.log("Deploying CollateralizedLoan contract...");

    const CollateralizedLoan = await hre.ethers.getContractFactory(
        "CollateralizedLoan"
    );
    const loan = await CollateralizedLoan.deploy();

    await loan.waitForDeployment();

    const address = await loan.getAddress();
    console.log("CollateralizedLoan deployed to:", address);

    // Wait for few block confirmations
    await loan.deploymentTransaction().wait(6);

    // Verify contract on Etherscan
    console.log("Verifying contract on Etherscan...");
    try {
        await hre.run("verify:verify", {
            address: address,
            constructorArguments: [],
        });
        console.log("Contract verified on Etherscan!");
    } catch (error) {
        console.error("Error verifying contract:", error);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
