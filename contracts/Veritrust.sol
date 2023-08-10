// SPDX-License-Identifier: UNLICENCED
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

// chequeo de la cantidad de participantes y la cantidad de reveals
// modificar estas listas si se cancela una bid

/**
 * @title Veritrust
 * @dev This contract handles the bidding process and winner selection for a tender.
 */
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

    /**
     * @dev Constructor to initialize the Veritrust contract.
     * @param _owner The address that will initially own the contract.
     * @param _name The name of the Veritrust contract.
     * @param _ipfsUrl The IPFS URL associated with the contract.
     * @param _deadline The deadline timestamp for the contract.
     */
    constructor(address _owner, string memory _name, string memory _ipfsUrl, uint256 _deadline) {
        require(_deadline > block.timestamp, "Deadline must be in the future");
        transferOwnership(_owner);
        name = _name;
        ipfsUrl = _ipfsUrl;
        deadline = _deadline;
    }

    /**
     * @dev Places a bid in the contract.
     * @param _bidderName The name of the bidder.
     * @param _urlHash The hash of the URL associated with the bid.
     * @param _price The bid price.
     */
    function setBid(string memory _bidderName, bytes32 _urlHash, uint256 _price) public beforeDeadline {
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

    /**
     * @dev Reveals a bid after the deadline has passed.
     * @param _url The URL associated with the bid.
     */
    function revealBid(string memory _url) public afterDeadline {
        require(bids[msg.sender].timestamp > 0, "Bid doesnt exist");
        require(uint256(keccak256(abi.encodePacked(_url))) == uint256(bids[msg.sender].urlHash));
        bids[msg.sender].url = _url;
        bids[msg.sender].revealed = true;

        emit BidRevealed(bids[msg.sender]);
    }

    /**
     * @dev Selects the winner of the bid and sets their address.
     * @param _winner The address of the selected winner.
     * @return The address of the selected winner.
     */
    function choseWinner(address _winner) public onlyOwner afterDeadline returns (address) {
        require(bids[msg.sender].revealed == true, "Bid not yet revealed");
        winner = _winner;
        
        emit Winner(name, _winner, ipfsUrl);

        return _winner;
    }
    
    /**
     * @dev Extends the deadline of the contract.
     * @param _newDeadline The new deadline timestamp.
     */
    function extendDeadline(uint256 _newDeadline) public onlyOwner {
        // chequear que no haya ningun reveal aun
        require(_newDeadline > deadline, "Deadlines can only be extended");
        deadline = _newDeadline;

        emit DeadlineExtended(_newDeadline);
    }
    
    /**
     * @dev Gets the list of bidders who participated in the bidding process.
     * @return An array containing the addresses of bidders.
     */
    function getBidders() public view afterDeadline returns (address[] memory) {
        return bidders;
    }

    /**
     * @dev Gets the number of bidders who participated in the bidding process.
     * @return The number of bidders.
     */
    function getNumberOfBidders() public view returns(uint256) {
        return bidders.length;
    }

}