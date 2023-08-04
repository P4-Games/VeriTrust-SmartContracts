// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./Veritrust.sol";

contract VeritrustFactory {

    Veritrust[] private veritrustContracts;

    event contractDeployed(Veritrust contractAddress);

    function deployVeritrust(string memory _name) public {
        Veritrust veritrustContract = new Veritrust(_name);
        veritrustContracts.push(veritrustContract);

        emit contractDeployed(veritrustContract);
    }

    function getContracts() public view returns(Veritrust[] memory){
        return veritrustContracts;
    }
}