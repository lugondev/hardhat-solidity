import { BigNumber } from "@ethersproject/bignumber";
import { ethers } from "hardhat";

async function main() {
  const factory = await ethers.getContractFactory("MillionDotToken");

  // If we had constructor arguments, they would be passed into deploy()
  let contract = await factory.deploy(
    "TokenName", "TKS",
    BigNumber.from(10000).mul(BigNumber.from(10).pow(18)),
    BigNumber.from(1000000).mul(BigNumber.from(10).pow(18)),
    "0x90Dc10E28f4c079d9B6537e10Cb2dee22f721CbB"
  );

  // The address the Contract WILL have once mined
  console.log(contract.address);

  // The transaction that was sent to the network to deploy the Contract
  console.log(contract.deployTransaction.hash);

  // The contract is NOT deployed yet; we must wait until it is mined
  await contract.deployed();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
