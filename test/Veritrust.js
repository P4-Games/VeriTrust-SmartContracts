const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Veritrust Smart Contract", function () {
  let veritrust;
  let owner;
  let bidder1;

  beforeEach(async function () {
    [owner, bidder1] = await ethers.getSigners();

    const Veritrust = await ethers.getContractFactory("Veritrust");
    veritrust = await Veritrust.deploy(
      owner.address,
      "ContractName",
      "IPFSURL",
      172800,
      172800,
      10,
      20
    );

    await veritrust.deployed();
  });

  it("should set a bid", async function () {
    const bidderName = "Bidder1";
    const urlHash = "0x1234567890123456789012345678901234567890123456789012345678901234";
    const bidFee = 10;
    const warrantyFee = 20;

    const initialBalance = await ethers.provider.getBalance(veritrust.address);

    await expect(veritrust.setBid(bidderName, urlHash, { value: bidFee + warrantyFee }));

    const newBalance = await ethers.provider.getBalance(veritrust.address);
    
    expect(newBalance).to.equal(initialBalance.add(warrantyFee));
  });

  // Add more test cases here
});
