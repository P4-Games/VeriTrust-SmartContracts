// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test, console } from "forge-std/Test.sol";
import { HelperConfig } from "../script/HelperConfig.s.sol";
import { DeployVeritrustFactory } from "../script/DeployVeritrustFactory.s.sol";
import "../src/VeritrustFactory.sol";
import { OracleMock } from "../src/OracleMock.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VeritrustFactoryTest is Test {
    address owner = address(uint160(vm.envUint("EOA_ADDRESS")));
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    VeritrustFactory public factory;
    HelperConfig public helperConfig;
    OracleMock public oracle;

    function setUp() public {
        // mainnetFork = vm.createFork(MAINNET_RPC_URL);
        // vm.selectFork(mainnetFork);
        DeployVeritrustFactory deployVeritrustFactory = new DeployVeritrustFactory();
        (factory, helperConfig) = deployVeritrustFactory.run();

        vm.deal(owner, 1000 ether);
        vm.deal(alice, 1000 ether);
        vm.deal(bob, 1000 ether);
    }

    function test_Full_Veristrust_Without_Arbitration() public {
        string memory name = "Test";
        string memory ipfsUrl = "www.test.com.ar";
        uint128 commitDeadline = 172_800;
        uint128 revealDeadline = 172_800;
        uint256 warrantyAmount = 1 ether;

        vm.startPrank(owner);
        factory.deployVeritrust{ value: factory.getDeployCost() }(name, ipfsUrl, commitDeadline, revealDeadline, warrantyAmount);
        Veritrust veritrust = factory.getContracts()[0];

        vm.startPrank(alice);
        veritrust.setBid{ value: veritrust.getBidCost() }("alice", bytes32(keccak256(abi.encodePacked("http://alice"))));
        assertEq(1, veritrust.getNumberOfBidders());

        vm.startPrank(bob);
        veritrust.setBid{ value: veritrust.getBidCost() }("bob", bytes32(keccak256(abi.encodePacked("http://bob"))));
        assertEq(2, veritrust.getNumberOfBidders());

        vm.warp(block.timestamp + commitDeadline);

        vm.startPrank(alice);
        veritrust.revealBid("http://alice");

        vm.startPrank(bob);
        veritrust.revealBid("http://bob");

        vm.warp(block.timestamp + revealDeadline);

        vm.startPrank(owner);
        veritrust.choseWinner(bob);

        assertEq(veritrust.winner(), bob);
        assertEq(address(veritrust).balance, 0);
    }
}
