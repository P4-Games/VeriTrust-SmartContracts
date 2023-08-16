const { expect } = require("chai");
const { getContractAddress } = require("ethers/lib/utils");
const { ethers } = require("hardhat");

describe("Veritrust Smart Contract", function () {
  let veritrustFactory;
  let owner;
  let bidder;
  let veritrustContractAddress;

  const bidFee = ethers.utils.parseEther("0.002");
  const deployFee = ethers.utils.parseEther("0.001");
  const warrantyAmount = ethers.utils.parseEther("0.003");

  const deployVeritrust = async () => {
    const tx = await veritrustFactory.connect(licitante).deployVeritrust(
      "Veritrust Test",
      "www.com.ar",
      172800,
      172800,
      warrantyAmount,
    { value: deployFee })
    
    const receipt = await tx.wait()
    console.log(receipt.events.forEach(event => console.log(event)))

    veritrustContractAddress = receipt.events.filter(event => event.event == "ContractDeployed")[0].args.contractAddress;

    return await ethers.getContractAt("Veritrust", veritrustContractAddress);

  }

  beforeEach(async function () {

    [owner, licitante, bidder] = await ethers.getSigners();
    
    const VeritrustFactory = await ethers.getContractFactory("VeritrustFactory");
    
    veritrustFactory = await VeritrustFactory.deploy(
      deployFee,
      bidFee
    );
    await veritrustFactory.deployed();

  });

  it.skip("Should deploy veritrust contract", async function () {
    
    let veritrust = await deployVeritrust();
    
  }); 

  
  it("should set a bid", async function () {
    const bidderName = "Bidder1";
    const urlHash = "0x1234567890123456789012345678901234567890123456789012345678901234";

    let veritrust = await deployVeritrust();

    const initialBalance = await ethers.provider.getBalance(veritrust.address);
    console.log(await ethers.provider.getBalance(bidder.address));

    // console.log({ bidFee }, { warrantyAmount })

    expect(await veritrust.connect(bidder).setBid(bidderName, urlHash, { value: bidFee + warrantyAmount }));

    const newBalance = await ethers.provider.getBalance(veritrust.address);
    
    expect(newBalance).to.equal(initialBalance.add(warrantyFee));
  });
  
});