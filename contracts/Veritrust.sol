// SPDX-License-Identifier: UNLICENCED
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Veritrust is Ownable {

    string public name;
    string public ipfsUrl;
    uint256 deadline;
    mapping(address bidder => Bid bidData) public bids;

    constructor(string memory _name, string memory _ipfsUrl, uint256 _deadline) {
        require(_deadline > block.timestamp, "Deadline must be in the future");
        name = _name;
        ipfsUrl = _ipfsUrl;
        deadline = _deadline;
    }

    struct Bid {
        string bidder;
        string url;
        uint256 timestamp;
        uint256 price;
    }

    event NewBid(string bidder);
    event DeadlineExtended(uint256 newDeadline);

    function bidForTender(string memory _bidder, string memory _url, uint256 _price) public {
        bids[msg.sender].bidder = _bidder;
        bids[msg.sender].url = _url;
        bids[msg.sender].timestamp = block.timestamp;
        bids[msg.sender].price = _price;

        emit NewBid(_bidder);
    }
    
    function extendDeadline(uint256 _newDeadline) public onlyOwner {
        require(_newDeadline > deadline, "Deadlines can only be extended");
        deadline = _newDeadline;

        emit DeadlineExtended(_newDeadline);
    }

}