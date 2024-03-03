const { ethers, run } = require("hardhat");
const { deploymentFile } = require("../config");
const storeDeploymentData = require("../storeDeploymentData");

async function main() {
  console.log("Starting the entire contract deployment...");
  const provider = new ethers.JsonRpcProvider("http://127.0.0.1:8545/");
  const signer = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
  const baseTokenUri = "ipfs://QmYeU3QK6jMrYCQ8kSmV7GKqZmEgGaWdoRSV6eB7zqCn2G/";

  // Deployment of NewenToken
  console.log("Now the NewenToken will be deployed");
  const NewenToken = await ethers.deployContract("NewenToken", []);
  await NewenToken.waitForDeployment();
  console.log(`NewenToken deployed at: ${NewenToken.target}`);

  // Deployment of AnkyWriters
  console.log("Now the AnkyWriters will be deployed");
  const AnkyWriters = await ethers.deployContract("AnkyWriters", [
    "Anky Writers",
    "ANKYW",
    8888,
    NewenToken.target,
  ]);
  await AnkyWriters.waitForDeployment();
  console.log(`AnkyWriters deployed at: ${AnkyWriters.target}`);

  await run("verify:verify", {
    address: NewenToken.target,
    constructorArguments: [],
  });

  await run("verify:verify", {
    address: AnkyWriters.target,
    constructorArguments: ["Anky Writers", "ANKYW", 8888, NewenToken.target],
  });

  await run("verify:verify", {
    address: AnkyDementor.target,
    constructorArguments: [AnkyAirdrop.target],
  });

  console.log("All contracts deployed and verified!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
