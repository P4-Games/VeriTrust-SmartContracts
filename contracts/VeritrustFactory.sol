// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./Veritrust.sol";

/**
 * @title VeritrustFactory
 * @dev This contract acts as a factory for creating Veritrust contracts.
 */
contract VeritrustFactory {

    Veritrust[] private veritrustContracts;

    /**
     * @dev Emitted when a new Veritrust contract is deployed.
     * @param contractAddress The address of the deployed Veritrust contract.
     * @param owner The owner who deployed the Veritrust contract.
     */
    event ContractDeployed(Veritrust contractAddress, address owner);

    /**
     * @dev Deploys a new Veritrust contract.
     * @param _name The name of the Veritrust contract.
     * @param _ipfsUrl The IPFS URL associated with the contract.
     */
    function deployVeritrust(string memory _name, string memory _ipfsUrl, uint128 _commitDeadline, uint128 _revealDeadline) public {
        Veritrust veritrustContract = new Veritrust(msg.sender, _name, _ipfsUrl, _commitDeadline, _revealDeadline);
        veritrustContracts.push(veritrustContract);

        emit ContractDeployed(veritrustContract, msg.sender);
    }

    /**
     * @dev Retrieves the array of deployed Veritrust contracts.
     * @return An array containing references to deployed Veritrust contracts.
     */
    function getContracts() public view returns (Veritrust[] memory){
        return veritrustContracts;
    }
}
