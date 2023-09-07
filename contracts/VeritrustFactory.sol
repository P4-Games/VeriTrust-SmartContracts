// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./Veritrust.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title VeritrustFactory
 * @dev This contract acts as a factory for creating Veritrust contracts.
 */
contract VeritrustFactory is Ownable {

    AggregatorV3Interface internal dataFeed;

    Veritrust[] private veritrustContracts;
    uint256 public deployFee;
    uint256 public bidFee;

    /**
     * @dev Emitted when a new Veritrust contract is deployed.
     * @param contractAddress The address of the deployed Veritrust contract.
     * @param owner The owner who deployed the Veritrust contract.
     */
    event ContractDeployed(Veritrust contractAddress, address owner);
    event FundsWithdrawn(uint256 balance);
    
    constructor(uint256 _deployFee, uint256 _bidFee, address _chainlinkAddress) {
        deployFee = _deployFee;
        bidFee = _bidFee;
        // 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        dataFeed = AggregatorV3Interface(_chainlinkAddress);
    }
    
    /**
     * @dev Deploys a new Veritrust contract.
     * @param _name The name of the Veritrust contract.
     * @param _ipfsUrl The IPFS URL associated with the contract.
     */
    function deployVeritrust(string memory _name, string memory _ipfsUrl, uint128 _commitDeadline, uint128 _revealDeadline, uint256 warrantyAmount) public payable {
        Veritrust veritrustContract = new Veritrust(msg.sender, _name, _ipfsUrl, _commitDeadline, _revealDeadline, bidFee, warrantyAmount);
        veritrustContracts.push(veritrustContract);
        
        require(msg.value == deployFee, "Incorrect payment fee");
        
        emit ContractDeployed(veritrustContract, msg.sender);
    }

    function withdrawBalance() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "Transfer failed");
        
        emit FundsWithdrawn(balance);
    }

    /**
     * @dev Retrieves the array of deployed Veritrust contracts.
     * @return An array containing references to deployed Veritrust contracts.
     */
    function getContracts() public view returns (Veritrust[] memory){
        return veritrustContracts;
    }

    function getLatestData() public view returns (int) {
        (
            /* uint80 roundID */,
            int answer,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = dataFeed.latestRoundData();
        uint decimals = 18 - dataFeed.decimals();
        return answer * int(10 ** decimals);
    }

    receive() external payable {}
}