// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Veritrust} from "./Veritrust.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title VeritrustFactory
 * @dev This contract acts as a factory for creating Veritrust contracts.
 */
contract VeritrustFactory is Ownable {
    AggregatorV3Interface internal dataFeed;

    uint256 public deployFee;
    uint256 public bidFee;
    Veritrust[] private veritrustContracts;

    /**
     * @dev Emitted when a new Veritrust contract is deployed.
     * @param contractAddress The address of the deployed Veritrust contract.
     * @param owner The owner who deployed the Veritrust contract.
     */
    event ContractDeployed(
        Veritrust contractAddress,
        address owner,
        string name,
        string ipfsUrl
    );
    event FundsWithdrawn(uint256 balance);

    /// @notice Initializes the contract with the specified deployment and bid fees, Chainlink data feed address,
    /// and Meta Pool Staking contract address.
    /// @param _deployFee The deployment fee to set. Amount must be in USD with 18 decimals (e.g.: 50 USD = 50000000000000000000)
    /// @param _bidFee The bid fee to set. Amount must be in USD with 18 decimals (e.g.: 5 USD = 5000000000000000000)
    /// @param _chainlinkAddress The address of the Chainlink data feed contract.
    constructor(
        uint256 _deployFee,
        uint256 _bidFee,
        address _chainlinkAddress
    ) {
        deployFee = _deployFee;
        bidFee = _bidFee;

        // 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419 (Mainnet)
        // 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e (Goerli)
        dataFeed = AggregatorV3Interface(_chainlinkAddress);
    }

    /**
     * @dev Deploys a new Veritrust contract.
     * @param _name The name of the Veritrust contract.
     * @param _ipfsUrl The IPFS URL associated with the contract.
     * @param warrantyAmount The amount of the warranty to be deposited by the seller. Amount is in WEI.
     */
    function deployVeritrust(
        string memory _name,
        string memory _ipfsUrl,
        uint128 _commitDeadline,
        uint128 _revealDeadline,
        uint256 warrantyAmount
    ) public payable {
        require(msg.value == getDeployCost(), "Incorrect payment fee");

        Veritrust veritrustContract = new Veritrust(
            msg.sender,
            _name,
            _ipfsUrl,
            _commitDeadline,
            _revealDeadline,
            bidFee,
            warrantyAmount
        );
        veritrustContracts.push(veritrustContract);

        emit ContractDeployed(veritrustContract, msg.sender, _name, _ipfsUrl);
    }

    function withdrawBalance() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "Transfer failed");

        emit FundsWithdrawn(balance);
    }

    function setDeployFee(uint256 _newFee) public onlyOwner {
        deployFee = _newFee;
    }

    function setBidFee(uint256 _newFee) public onlyOwner {
        bidFee = _newFee;
    }

    /**
     * @dev Retrieves the array of deployed Veritrust contracts.
     * @return An array containing references to deployed Veritrust contracts.
     */
    function getContracts() public view returns (Veritrust[] memory) {
        return veritrustContracts;
    }

    /**
     * @dev Calculates the total deploy cost (set in USD) in ether.
     * @return The total deploy cost in ether.
     */
    function getDeployCost() public view returns (uint256) {
        int256 etherPrice = getLatestData();
        return uint256(int256(deployFee * 1 ether) / etherPrice);
    }

    // returns e.g.: 1645416823290000000000
    function getLatestData() public view returns (int256) {
        (
            ,
            /* uint80 roundID */
            int256 answer,
            ,
            ,

        ) = /*uint startedAt*/
            /*uint timeStamp*/
            /*uint80 answeredInRound*/
            dataFeed.latestRoundData();
        uint256 decimals = 18 - dataFeed.decimals();
        return answer * int256(10 ** decimals);
    }

    receive() external payable {}
}
