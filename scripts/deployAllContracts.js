const { ethers, run } = require("hardhat");
const { deploymentFile } = require("../config");
const storeDeploymentData = require("../storeDeploymentData");

async function main() {
  console.log("Starting the entire contract deployment...");
  const provider = new ethers.JsonRpcProvider("http://127.0.0.1:8545/");
  const signer = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

  const AnkyDiaries = await ethers.deployContract("AnkyDiaries", []);
  await AnkyDiaries.waitForDeployment();
  console.log(`AnkyDiaries deployed at: ${AnkyDiaries.target}`);

  await run("verify:verify", {
    address: AnkyDiaries.target,
    constructorArguments: [],
  });

  console.log("All contracts deployed and verified!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
