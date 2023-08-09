// SPDX-License-Identifier: UNLICENCED
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

// chequeo de la cantidad de participantes y la cantidad de reveals
// modificar estas listas si se cancela una bid

contract Veritrust is Ownable {

    struct Bid {
        string bidder;
        bytes32 urlHash;
        string url;
        uint256 timestamp;
        uint256 price;
        uint256 version;
        bool revealed;
    }

    // enum Status{open, closed, finished}
    // Status public tenderStatus;

    string public name;
    string public ipfsUrl;
    uint256 deadline;
    address public winner;
    mapping(address bidder => Bid bidData) private bids;
    address[] private bidders;

    event NewBid(string bidder);
    event BidRevealed(Bid bid);
    event Winner(string name, address winner, string ipfsUrl);
    event DeadlineExtended(uint256 newDeadline);

    modifier beforeDeadline {
        require(block.timestamp < deadline, "Deadline has passed");
        _;
    }

    modifier afterDeadline {
        require(block.timestamp >= deadline, "Wait until deadline");
        _;
    }

    constructor(address _owner, string memory _name, string memory _ipfsUrl, uint256 _deadline) {
        require(_deadline > block.timestamp, "Deadline must be in the future");
        transferOwnership(_owner);
        name = _name;
        ipfsUrl = _ipfsUrl;
        deadline = _deadline;
    }

    function setBid(string memory _bidderName, bytes32 _urlHash, uint256 _price) public  beforeDeadline {
        // require(bids[msg.sender].timestamp == 0, "Bid already placed");
        require(bidders.length < 101, "Up to 100 bidders only");
        
        bids[msg.sender].timestamp = block.timestamp;
        bids[msg.sender].bidder = _bidderName;
        bids[msg.sender].urlHash = _urlHash;
        bids[msg.sender].price = _price;
        bids[msg.sender].version++;

        bidders.push(msg.sender);

        emit NewBid(_bidderName);
    }

    function cancelBid() public {}

    function revealBid(bytes32 _urlHash, string memory _url) public afterDeadline {
        require(bids[msg.sender].timestamp > 0, "Bid doesnt exist");
        require(uint256(keccak256(abi.encodePacked(_url))) == uint256(_urlHash));
        bids[msg.sender].url = _url;
        bids[msg.sender].revealed = true;

        emit BidRevealed(bids[msg.sender]);
    }

    function choseWinner(address _winner) public onlyOwner afterDeadline returns(address) {
        require(bids[msg.sender].revealed == true, "Bid not yet revealed");
        winner = _winner;
        
        emit Winner(name, _winner, ipfsUrl);

        return _winner;
    }
    
    function extendDeadline(uint256 _newDeadline) public onlyOwner {
        // chequear que no haya ningun reveal aun
        require(_newDeadline > deadline, "Deadlines can only be extended");
        deadline = _newDeadline;

        emit DeadlineExtended(_newDeadline);
    }

    function getBidders() public view afterDeadline returns (address[] memory biddersList) {
        return bidders;
    }

    function getNumberOfBidders() public view returns(uint256) {
        return bidders.length;
    }

}