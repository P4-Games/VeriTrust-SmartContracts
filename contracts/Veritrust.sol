// SPDX-License-Identifier: UNLICENCED
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IVeritrustFactory {
    function getLatestData() external view returns (int);
}

/**
 * @title Veritrust
 * @dev This contract handles the bidding process and winner selection for a tender.
 */

contract Veritrust is Ownable {

    struct Bid {
        string bidder;
        string url;
        bytes32 urlHash;
        uint256 timestamp;
        uint256 version;
        address bidderAddress;
        bool revealed;
    }

    string public name;
    string public ipfsUrl;
    uint128 commitDeadline;
    uint128 revealDeadline;
    address public winner;
    mapping(address bidder => Bid bidData) private bids;
    address[] private bidders;
    uint256 private startBid;
    uint256 public validBids;
    
    address payable private factoryContract;
    uint256 private bidFee;
    uint256 public warrantyAmount;

    event BidRevealed(Bid bid);
    event Winner(string name, address winner, string ipfsUrl);
    event CommitDeadlineExtended(uint256 newDeadline);
    event RevealDeadlineExtended(uint256 newDeadline);
    event BidCancelled();

    modifier beforeCommitDeadline {
        require(block.timestamp < startBid + commitDeadline, "Commit deadline has passed");
        _;
    }

    modifier afterCommitDeadline {
        require(block.timestamp >= startBid + commitDeadline, "Wait until commit deadline");
        _;
    }

    modifier beforeRevealDeadline {
        require(block.timestamp < startBid + commitDeadline + revealDeadline, "Reveal deadline has passed");
        _;
    }

    modifier afterRevealDeadline {
        require(block.timestamp >= startBid + commitDeadline + revealDeadline, "Wait until reveal deadline");
        _;
    }

    /**
     * @dev Constructor to initialize the Veritrust contract.
     * @param _owner The address that will initially own the contract.
     * @param _name The name of the Veritrust contract.
     * @param _ipfsUrl The IPFS URL associated with the contract.
     * @param _commitDeadline seconds until commit is possible.
     * @param _revealDeadline seconds past commit until reveal is posssible.
     * @param _bidFee Fee value for bids.
     */
    constructor(address _owner, string memory _name, string memory _ipfsUrl, uint128 _commitDeadline, uint128 _revealDeadline, uint256 _bidFee, uint256 _warrantyAmount) {
        require(_commitDeadline > 1 days, "Commit deadline must be be greater than 1 day");
        require(_revealDeadline > 1 days, "Reveal deadline must be greater than 1 day");
        transferOwnership(_owner);
        name = _name;
        ipfsUrl = _ipfsUrl;
        startBid = block.timestamp;
        commitDeadline =  _commitDeadline;
        revealDeadline = _revealDeadline;
        factoryContract = payable(msg.sender);
        bidFee = _bidFee;
        warrantyAmount = _warrantyAmount;
    }

    /**
     * @dev Places a bid in the contract.
     * @param _bidderName The name of the bidder.
     * @param _urlHash The hash of the URL associated with the bid.
     */
    function setBid(string memory _bidderName, bytes32 _urlHash) public beforeCommitDeadline payable {
        require(bidders.length < 101, "Up to 100 bidders only");
        uint256 bidCost = getBidCost();
        require(msg.value == bidCost, "Incorrect payment fee");

        Bid storage bid = bids[msg.sender];
        require(bid.version == 0, "Bid already exist");
        
        bid.timestamp = block.timestamp;
        bid.bidder = _bidderName;
        bid.urlHash = _urlHash;
        bid.bidderAddress = msg.sender;
        bid.version++;

        bidders.push(msg.sender);


        (bool success, ) = factoryContract.call{ value: bidCost - warrantyAmount }("");
        require(success, "Fee transfer fail");
    }

    function updateBid(bytes32 _urlHash) public beforeCommitDeadline  {
        Bid storage bid = bids[msg.sender];
        require(bid.version > 0, "Bid doesn't exist");
        
        bid.timestamp = block.timestamp;
        bid.urlHash = _urlHash;
        bid.version++;
    }

    /**
     * @dev Reveals a bid after the deadline has passed.
     * @param _url The URL associated with the bid.
     */
    function revealBid(string memory _url) public afterCommitDeadline beforeRevealDeadline {
        Bid storage bid = bids[msg.sender];
        require(bid.version > 0, "Bid doesnt exist");
        require(bid.revealed == false, "Bid already revealed");
        require(uint256(keccak256(abi.encodePacked(_url))) == uint256(bid.urlHash));
        bid.url = _url;
        bid.revealed = true;
        validBids++;

        (bool success, ) = payable(msg.sender).call{ value: warrantyAmount }("");
        require(success, "Transfer failed");

        emit BidRevealed(bid);
    }

    /**
     * @dev Selects the winner of the bid and sets their address.
     * @param _winner The address of the selected winner.
     */
    function choseWinner(address _winner) public onlyOwner afterRevealDeadline {
        require(bids[_winner].revealed == true, "Bid not yet revealed");
        winner = _winner;

        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success, "Transfer failed");

        emit Winner(name, _winner, ipfsUrl);
    }

    function cancelBids() public onlyOwner afterRevealDeadline {
        require(validBids == 0, "There are valid bids");
        
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success, "Transfer failed");

        emit BidCancelled();
    }
    
    /**
     * @dev Extends the deadline of the contract.
     * @param _newDeadline The new deadline timestamp.
     */
    function extendCommitDeadline(uint128 _newDeadline) public onlyOwner beforeCommitDeadline {
        require(_newDeadline > commitDeadline, "Deadlines can only be extended");
        commitDeadline = _newDeadline;

        emit CommitDeadlineExtended(startBid + _newDeadline);
    }

    /**
     * @dev Extends the deadline of the contract.
     * @param _newDeadline The new deadline timestamp.
     */
    function extendRevealDeadline(uint128 _newDeadline) public onlyOwner beforeRevealDeadline {
        // chequear que no haya ningun reveal aun
        require(_newDeadline > revealDeadline, "Deadlines can only be extended");
        revealDeadline = _newDeadline;

        emit RevealDeadlineExtended(startBid + commitDeadline + _newDeadline);
    }
    
    /**
     * @dev Gets the list of bidders who participated in the bidding process.
     * @return An array containing the list of bids.
     */
    function getBidders() public view afterCommitDeadline returns (Bid[] memory) {
        Bid[] memory bidList = new Bid[](bidders.length);
        for (uint256 i = 0; i < bidders.length;) {
            bidList[i] = bids[bidders[i]];
            unchecked {
                i++;
            }
        }
        return bidList;
    }

    /**
     * @dev Gets the number of bidders who participated in the bidding process.
     * @return The number of bidders.
     */
    function getNumberOfBidders() public view returns(uint256) {
        return bidders.length;
    }

    function getBidCost() public view returns(uint256) {
        int256 etherPrice = IVeritrustFactory(factoryContract).getLatestData();
        return uint256(int256(bidFee * 1 ether) / etherPrice) + warrantyAmount;
    }

    receive() external payable {}
}