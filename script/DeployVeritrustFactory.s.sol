// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VeritrustFactory} from "../src/VeritrustFactory.sol";

contract DeployVeritrustFactory is Script {
    
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    function run() external returns(VeritrustFactory, HelperConfig){
      HelperConfig helperConfig = new HelperConfig();
      (address priceFeed, uint256 deployFee, uint256 bidFee) = helperConfig.activeNetworkConfig();
      
      vm.startBroadcast(deployerPrivateKey);
      VeritrustFactory veritrustFactory = new VeritrustFactory(deployFee, bidFee, priceFeed);
      vm.stopBroadcast();
      
      return (veritrustFactory, helperConfig);
    }
}
