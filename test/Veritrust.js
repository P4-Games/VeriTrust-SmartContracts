const { time } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");
const { getContractAddress } = require("ethers/lib/utils");
const { ethers } = require("hardhat");

describe("Veritrust Smart Contract", function () {
  let veritrustFactory;
  let owner;
  let bidder;

  const bidFee = ethers.utils.parseEther("5");
  const deployFee = ethers.utils.parseEther("50");
  const warrantyAmount = ethers.utils.parseEther("1");
  const commitDeadline = 172800;
  const revealDeadline = 172800;


  const deployVeritrust = async () => {
    const tx = await veritrustFactory.connect(licitante).deployVeritrust(
      "Veritrust Test",
      "www.com.ar",
      commitDeadline,
      revealDeadline,
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
    
    const OracleMock = await ethers.getContractFactory("OracleMock");
    const oracleMock = await OracleMock.deploy();
    await oracleMock.deployed();
  
    const VeritrustFactory = await ethers.getContractFactory("VeritrustFactory");
    veritrustFactory = await VeritrustFactory.deploy(
      deployFee,
      bidFee,
      oracleMock.address
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
   
    const factoryBalance = await ethers.provider.getBalance(veritrustFactory.address);
    const initialBalance = await ethers.provider.getBalance(veritrust.address);
    
    const bidCost = await veritrust.getBidCost();
    await veritrust.connect(bidder).setBid(bidderName, urlHash, { value: bidCost });
    
    const newBalance = await ethers.provider.getBalance(veritrust.address);
    const newFactoryBalance = await ethers.provider.getBalance(veritrustFactory.address);
    const warranty = await veritrust.warrantyAmount();
    
    expect(newBalance).to.equal(initialBalance.add(warranty));
    expect(newFactoryBalance).to.equal(factoryBalance.add(bidCost.sub(warranty)));
  });
 
  it("should throw at set a bid", async function () {
    const bidderName = "Bidder1";
    const urlHash = "0x1234567890123456789012345678901234567890123456789012345678901234";
    const veritrust = await deployVeritrust();
   
    const initialBalance = await ethers.provider.getBalance(veritrust.address);
    
    await expect(veritrust.connect(bidder).setBid(bidderName, urlHash, { value: 3 })).to.be.revertedWith("Incorrect payment fee");

    const newBalance = await ethers.provider.getBalance(veritrust.address);
    
    expect(newBalance).to.equal(initialBalance);
  });

  it("reveal and all is correct", async function () {
    const bidderName = "Bidder1";
    const url = "https://veritrust/secret";
    const urlHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(url));
    const veritrust = await deployVeritrust();
   
    const bidCost = await veritrust.getBidCost();
    
    await veritrust.connect(bidder).setBid(bidderName, urlHash, { value: bidCost });
    const initialBalance = await ethers.provider.getBalance(bidder.address);
    
    await time.increase(commitDeadline);
  
    const tx = await veritrust.connect(bidder).revealBid(url);
    const receipt = await tx.wait();
    const gasUsed = BigInt(receipt.cumulativeGasUsed) * BigInt(receipt.effectiveGasPrice);
    
    const veritrustBalance = await ethers.provider.getBalance(veritrust.address);
    expect(0).to.equal(veritrustBalance);

    const newBalance = await ethers.provider.getBalance(bidder.address);

    expect(newBalance).to.equal(initialBalance.add(warrantyAmount).sub(gasUsed));
  });


  it("reveal and choose winner", async function () {
    const bidderName = "Bidder1";
    const url = "https://veritrust/secret";
    const urlHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(url));
    const veritrust = await deployVeritrust();
   
    const bidCost = await veritrust.getBidCost();
    
    await veritrust.connect(bidder).setBid(bidderName, urlHash, { value: bidCost });
    const initialBalance = await ethers.provider.getBalance(bidder.address);
    
    await time.increase(commitDeadline);
  
    const tx = await veritrust.connect(bidder).revealBid(url);
    await tx.wait();
    await time.increase(revealDeadline);

    await veritrust.connect(licitante).choseWinner(bidder.address);

  });

});