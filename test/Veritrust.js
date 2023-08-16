const { expect } = require("chai");
const { getContractAddress } = require("ethers/lib/utils");
const { ethers } = require("hardhat");

describe("Veritrust Smart Contract", function () {
  let veritrustFactory;
  let owner;
  let bidder;

  const bidFee = ethers.utils.parseEther("0.1");
  const deployFee = ethers.utils.parseEther("0.5");
  const warrantyAmount = ethers.utils.parseEther("1");

  const deployVeritrust = async () => {
    const tx = await veritrustFactory.connect(licitante).deployVeritrust(
      "Veritrust Test",
      "www.com.ar",
      172800,
      172800,
      warrantyAmount,
    { value: deployFee })
    
    const receipt = await tx.wait()
   
    const veritrustContractAddress = receipt.events.filter(event => event.event == "ContractDeployed")[0].args.contractAddress;
    const Veritrust = await ethers.getContractFactory("Veritrust");
    const veritrust = Veritrust.attach(veritrustContractAddress);
    await veritrust.deployed();
    return veritrust;

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
    await deployVeritrust();    
  }); 

  
  it("should set a bid", async function () {
    const bidderName = "Bidder1";
    const urlHash = "0x1234567890123456789012345678901234567890123456789012345678901234";
    const veritrust = await deployVeritrust();
   
    const initialBalance = await ethers.provider.getBalance(veritrust.address);
   
    await veritrust.connect(bidder).setBid(bidderName, urlHash, { value: bidFee.add(warrantyAmount) });

    const newBalance = await ethers.provider.getBalance(veritrust.address);
    
    expect(newBalance).to.equal(initialBalance.add(warrantyAmount));
  });
 
  it("should throw at set a bid", async function () {
    const bidderName = "Bidder1";
    const urlHash = "0x1234567890123456789012345678901234567890123456789012345678901234";
    const veritrust = await deployVeritrust();
   
    const initialBalance = await ethers.provider.getBalance(veritrust.address);
   
    await expect(veritrust.connect(bidder).setBid(bidderName, urlHash, { value: bidFee })).to.be.revertedWith("Incorrect payment fee");

    const newBalance = await ethers.provider.getBalance(veritrust.address);
    
    expect(newBalance).to.equal(initialBalance);
  });
  
});