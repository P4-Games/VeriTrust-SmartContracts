// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";
import { OracleMock } from "../src/OracleMock.sol";

contract HelperConfig is Script {
  NetworkConfig public activeNetworkConfig;
  
  struct NetworkConfig {
    address priceFeed;
    uint256 deployFee;
    uint256 bidFee;
  }
  
  constructor() {
    if(block.chainid == 1){
      activeNetworkConfig = getMainnetNetworkConfig();
    } else if(block.chainid == 5){
      activeNetworkConfig = getGoerliNetworkConfig();
    } else if(block.chainid == 11155111){
      activeNetworkConfig = getSepoliaNetworkConfig();
    } else {
      activeNetworkConfig = getLocalNetworkConfig();
    }
  }

  function getMainnetNetworkConfig() public pure returns (NetworkConfig memory mainnetNetworkConfig) {
    mainnetNetworkConfig = NetworkConfig({
      priceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419,
      deployFee: 5e19, // 50 usd
      bidFee: 5e18 // 5 usd
    });
  }

  function getGoerliNetworkConfig() public pure returns (NetworkConfig memory goerliNetworkConfig) {
    goerliNetworkConfig = NetworkConfig({
      priceFeed: 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e,
      deployFee: 5e19, // 50 usd
      bidFee: 5e18 // 5 usd
    });
  }

  function getSepoliaNetworkConfig() public pure returns (NetworkConfig memory sepoliaNetworkConfig) {
    sepoliaNetworkConfig = NetworkConfig({
      priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
      deployFee: 5e19, // 50 usd
      bidFee: 5e18 // 5 usd
    });
  }

  function getLocalNetworkConfig() public returns (NetworkConfig memory localNetworkConfig){
    if (activeNetworkConfig.priceFeed != address(0)) {
      return activeNetworkConfig;
    }

    vm.startBroadcast();
    OracleMock oracle = new OracleMock();
    vm.stopBroadcast();

    localNetworkConfig = NetworkConfig({
      priceFeed: address(oracle),
      deployFee: 5e19, // 50 usd
      bidFee: 5e18 // 5 usd
    });
  }
}