// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from 'forge-std/Test.sol';
import '../src/VeritrustFactory.sol';
import '../src/OracleMock.sol';

contract VeritrustFactoryTest is Test {
  address owner = makeAddr('owner');
  address alice = makeAddr('alice');
  address bob = makeAddr('bob');

  VeritrustFactory factory;
  OracleMock oracle;

  function setUp() public {
    oracle = new OracleMock();
    factory = new VeritrustFactory(1, 1, address(oracle));
  }

  function test_Increment() public {}

  function testFuzz_SetNumber(uint256 x) public {}
}
