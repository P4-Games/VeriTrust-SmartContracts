// PSDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";
import {VeritrustFactory} from "../src/VeritrustFactory.sol";
import {Veritrust} from "../src/Veritrust.sol";


contract DeployVeritrust is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    function run() external returns(Veritrust){
      address mostRecentlyDeployedFactory = DevOpsTools.get_most_recent_deployment("VeritrustFactory", block.chainid);

      VeritrustFactory factory = VeritrustFactory(payable(mostRecentlyDeployedFactory));

      string memory name = "Test Veritrust";
      string memory ipfsUrl = "ipfs://testabcdef";
      uint128 commitDeadline = 172000;
      uint128 revealDeadline = 172000;
      uint256 warrantyAmount = 1 ether;
      uint256 deployFee = factory.getDeployCost();
      require(deployFee < 0.1 ether, "Deploy fee too high");

      vm.startBroadcast(deployerPrivateKey);
      Veritrust veritrust = factory.deployVeritrust{value: deployFee}(name, ipfsUrl, commitDeadline, revealDeadline, warrantyAmount);
      vm.stopBroadcast();
      
      return (veritrust);
    }
}