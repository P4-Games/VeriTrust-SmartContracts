// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test, console } from "forge-std/Test.sol";
import "../src/VeritrustFactory.sol";
import { OracleMock } from "../src/OracleMock.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/MetaPool/Staking.sol";
import "../src/MetaPool/Withdrawal.sol";

contract VeritrustFactoryTest is Test {
    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    VeritrustFactory factory;
    OracleMock oracle;
    uint256 deployFee = 1 ether;
    uint256 bidFee = 1 ether;
    uint256 mainnetFork;
    string MAINNET_RPC_URL = "https://eth.llamarpc.com";

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);

        vm.deal(owner, 1000 ether);
        vm.deal(alice, 1000 ether);
        vm.deal(bob, 1000 ether);
        vm.startPrank(owner);

        oracle = new OracleMock();
        factory = new VeritrustFactory(deployFee, bidFee, address(oracle), 0x48AFbBd342F64EF8a9Ab1C143719b63C2AD81710);
    }

    function test_Create_Veristrust() public {
        string memory name = "Test";
        string memory ipfsUrl = "www.test.com.ar";
        uint128 commitDeadline = 172_800;
        uint128 revealDeadline = 172_800;
        uint256 warrantyAmount = 1 ether;

        factory.deployVeritrust{ value: factory.getDeployCost() }(name, ipfsUrl, commitDeadline, revealDeadline, warrantyAmount);
        Veritrust veritrust = factory.getContracts()[0];


        Staking staking = Staking(payable(0x48AFbBd342F64EF8a9Ab1C143719b63C2AD81710));
        Withdrawal withdrawal = Withdrawal(staking.withdrawal()); 
        vm.startPrank(withdrawal.owner());
        withdrawal.setWithdrawalsStartEpoch(0);

        vm.startPrank(alice);
        veritrust.setBid{ value: veritrust.getBidCost() }("alice", bytes32(keccak256(abi.encodePacked("http://alice"))));
        assertEq(1, veritrust.getNumberOfBidders());

        vm.startPrank(bob);
        veritrust.setBid{ value: veritrust.getBidCost() }("bob", bytes32(keccak256(abi.encodePacked("http://bob"))));
        assertEq(2, veritrust.getNumberOfBidders());

        vm.startPrank(0x8c89569355F321A91655CA520fC09Be5f6B0Ec4D);
        staking.requestEthFromLiquidPoolToWithdrawal(2.5 ether);

        vm.warp(block.timestamp + commitDeadline);

        vm.startPrank(alice);
        veritrust.revealBid("http://alice");
        vm.startPrank(bob);
        veritrust.revealBid("http://bob");

        vm.warp(block.timestamp + 10 days);

        console.log("balance pre ", payable(withdrawal).balance);
        veritrust.claimWarranty();
        console.log("balance post", payable(withdrawal).balance);
        
        console.log("balance veritrust bob", payable(veritrust).balance);
        vm.startPrank(alice);
        veritrust.claimWarranty();
        console.log("balance veritrust alice", payable(veritrust).balance);
    }
}
