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
        uint256 version;
        bool revealed;
    }

    // enum Status{open, closed, finished}
    // Status public tenderStatus;

    string public name;
    string public ipfsUrl;
    uint128 commitDeadline;
    uint128 revealDeadline;
    address public winner;
    mapping(address bidder => Bid bidData) private bids;
    address[] private bidders;
    uint256 private startBid;
    
    event NewBid(string bidder);
    event BidRevealed(Bid bid);
    event Winner(string name, address winner, string ipfsUrl);
    event CommitDeadlineExtended(uint256 newDeadline);
    event RevealDeadlineExtended(uint256 newDeadline);
    event BidCancelled(address indexed bidder);

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
     */
    constructor(address _owner, string memory _name, string memory _ipfsUrl, uint128 _commitDeadline, uint128 _revealDeadline) {
        require(_commitDeadline > 1 days, "Commit deadline must be be greater than 1 day");
        require(_revealDeadline > 1 days, "Reveal deadline must be greater than 1 day");
        transferOwnership(_owner);
        name = _name;
        ipfsUrl = _ipfsUrl;
        startBid = block.timestamp;
        commitDeadline =  _commitDeadline;
        revealDeadline = _revealDeadline;
    }

    /**
     * @dev Places a bid in the contract.
     * @param _bidderName The name of the bidder.
     * @param _urlHash The hash of the URL associated with the bid.
     */
    function setBid(string memory _bidderName, bytes32 _urlHash) public beforeCommitDeadline {
        // require(bids[msg.sender].timestamp == 0, "Bid already placed");
        require(bidders.length < 101, "Up to 100 bidders only");
        
        Bid storage bid = bids[msg.sender];
        bid.timestamp = block.timestamp;
        bid.bidder = _bidderName;
        bid.urlHash = _urlHash;
        bid.version++;

        bidders.push(msg.sender);

        emit NewBid(_bidderName);
    }

    function cancelBid() public beforeCommitDeadline {
        uint16 i;
        uint256 length = bidders.length;
        for(i;i<length;){
            if(bidders[i] == msg.sender){
                bidders[i] = bidders[length -1];
                bidders.pop();
                break;
            }
            unchecked {
                i++;
            }
        }

        require(length > bidders.length, "Bid not found");
        
        delete bids[msg.sender];
        
        // devolver $$$
        emit BidCancelled(msg.sender);
    }

    /**
     * @dev Reveals a bid after the deadline has passed.
     * @param _url The URL associated with the bid.
     */
    function revealBid(string memory _url) public afterCommitDeadline beforeRevealDeadline {
        Bid storage bid = bids[msg.sender];
        require(bid.timestamp > 0, "Bid doesnt exist");
        require(uint256(keccak256(abi.encodePacked(_url))) == uint256(bid.urlHash));
        bid.url = _url;
        bid.revealed = true;

        emit BidRevealed(bid);
    }

    /**
     * @dev Selects the winner of the bid and sets their address.
     * @param _winner The address of the selected winner.
     */
    function choseWinner(address _winner) public onlyOwner afterRevealDeadline {
        require(bids[msg.sender].revealed == true, "Bid not yet revealed");
        winner = _winner;
        
        emit Winner(name, _winner, ipfsUrl);
    }
    
    /**
     * @dev Extends the deadline of the contract.
     * @param _newDeadline The new deadline timestamp.
     */
    function extenCommitDeadline(uint128 _newDeadline) public onlyOwner beforeCommitDeadline {
        require(_newDeadline > commitDeadline, "Deadlines can only be extended");
        commitDeadline = _newDeadline;

        emit CommitDeadlineExtended(startBid + _newDeadline);
    }

    /**
     * @dev Extends the deadline of the contract.
     * @param _newDeadline The new deadline timestamp.
     */
    function extenRevealDeadline(uint128 _newDeadline) public onlyOwner beforeRevealDeadline {
        // chequear que no haya ningun reveal aun
        require(_newDeadline > revealDeadline, "Deadlines can only be extended");
        revealDeadline = _newDeadline;

        emit RevealDeadlineExtended(startBid + commitDeadline + _newDeadline);
    }
    
    /**
     * @dev Gets the list of bidders who participated in the bidding process.
     * @return An array containing the addresses of bidders.
     */
    function getBidders() public view afterCommitDeadline returns (address[] memory) {
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