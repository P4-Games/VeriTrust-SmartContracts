// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
const ethers = require('ethers')


async function main() {

  const VeritrustFactory = await hre.ethers.getContractFactory("VeritrustFactory")
  
  // uint256 _deployFee, uint256 _bidFee, address _chainlinkAddress
  const deployFee = ethers.BigNumber.from("1000000000000000000");
  const bidFee = ethers.BigNumber.from("1000000000000000000");
  const chainlinkAddressGoerli = "0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e"
  const veritrustFactory = await VeritrustFactory.deploy(deployFee, bidFee, chainlinkAddressGoerli);

  await veritrustFactory.deployed();

  console.log(
    `Veritrust factory contract deployed to ${veritrustFactory.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
