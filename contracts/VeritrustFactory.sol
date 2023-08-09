// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./Veritrust.sol";

contract VeritrustFactory {

    Veritrust[] private veritrustContracts;

    event contractDeployed(Veritrust contractAddress, address owner);

    function deployVeritrust(string memory _name, string memory _ipfsUrl, uint256 _deadline) public {
        Veritrust veritrustContract = new Veritrust(msg.sender, _name, _ipfsUrl, _deadline);
        veritrustContracts.push(veritrustContract);

        emit contractDeployed(veritrustContract, msg.sender);
    }

    function getContracts() public view returns(Veritrust[] memory){
        return veritrustContracts;
    }
}