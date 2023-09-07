// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console2 } from "forge-std/Test.sol";
import "../src/VeritrustFactory.sol";
import { OracleMock } from "../src/OracleMock.sol";

contract VeritrustFactoryTest is Test {
    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    VeritrustFactory factory;
    OracleMock oracle;
    uint256 deployFee = 1 ether;
    uint256 bidFee = 1 ether;

    function setUp() public {
        oracle = new OracleMock();
        factory = new VeritrustFactory(deployFee, bidFee, address(oracle));
    }

    function test_Create_Veristrust() public {
        string memory name = "Test";
        string memory ipfsUrl = "www.test.com.ar";
        uint128 commitDeadline = 172_800;
        uint128 revealDeadline = 172_800;
        uint256 warrantyAmount = 1 ether;

        factory.deployVeritrust{ value: 1 ether }(name, ipfsUrl, commitDeadline, revealDeadline, warrantyAmount);
    }

    function testFuzz_SetNumber(uint256 x) public { }
}
