// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

error AfterCommitDeadline();
error PastCommitDeadline();
error AfterRevealDeadline();
error PastRevealDeadline();
error DeadlineTooShort();
error TooManyBidders();
error InsufficientBidFee();
error BidAlreadyExists();
error BidDoesNotExist();
error BidAlreadyRevealed();
error BidNotRevealed();
error TransferFailed();
error InvalidUrl();
error ThereAreValidBids();
error InvalidDeadline();

interface IVeritrustFactory {
    function getLatestData() external view returns (int256);
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
        bool warrantyClaimed;
    }

    string public name;
    string public ipfsUrl;
    uint128 private commitDeadline;
    uint128 private revealDeadline;
    uint256 private startBid;
    uint256 public validBids;
    uint256 private bidFee;
    uint256 public warrantyAmount;
    address payable private factoryContract;
    address public winner;
    address[] private bidders;
    mapping(address bidder => Bid bidData) private bids;

    event BidSet(address tender, address bidder);
    event BidRevealed(Bid bid);
    event Winner(string name, address winner, string ipfsUrl);
    event CommitDeadlineExtended(uint256 newDeadline);
    event RevealDeadlineExtended(uint256 newDeadline);
    event BidCancelled();

    modifier beforeCommitDeadline() {
        if (block.timestamp >= startBid + commitDeadline)
            revert PastCommitDeadline();
        _;
    }

    modifier afterCommitDeadline() {
        if (block.timestamp < startBid + commitDeadline)
            revert AfterCommitDeadline();
        _;
    }

    modifier beforeRevealDeadline() {
        if (block.timestamp >= startBid + commitDeadline + revealDeadline)
            revert PastRevealDeadline();
        _;
    }

    modifier afterRevealDeadline() {
        if (block.timestamp < startBid + commitDeadline + revealDeadline)
            revert AfterRevealDeadline();
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
     * @param _warrantyAmount A warranty amount in eth that stays in the contract until reveal.
     */
    constructor(
        address _owner,
        string memory _name,
        string memory _ipfsUrl,
        uint128 _commitDeadline,
        uint128 _revealDeadline,
        uint256 _bidFee,
        uint256 _warrantyAmount
    ) {
        if (_commitDeadline <= 1 days || _revealDeadline <= 1 days) revert DeadlineTooShort();
        transferOwnership(_owner);
        name = _name;
        ipfsUrl = _ipfsUrl;
        startBid = block.timestamp;
        commitDeadline = _commitDeadline;
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
    function setBid(
        string memory _bidderName,
        bytes32 _urlHash
    ) external payable beforeCommitDeadline {
        if (bidders.length > 100) revert TooManyBidders();
        uint256 bidCost = getBidCost();
        if (msg.value < bidCost) revert InsufficientBidFee();

        Bid storage bid = bids[msg.sender];
        if (bid.version > 0) revert BidAlreadyExists();

        bid.timestamp = block.timestamp;
        bid.bidder = _bidderName;
        bid.urlHash = _urlHash;
        bid.bidderAddress = msg.sender;
        bid.warrantyClaimed = false;
        bid.version++;

        bidders.push(msg.sender);

        emit BidSet(address(this), msg.sender);

        (bool success, ) = factoryContract.call{
            value: bidCost - warrantyAmount
        }("");
        if (!success) revert TransferFailed();

        if (msg.value > bidCost) {
            (success, ) = payable(msg.sender).call{value: msg.value - bidCost}(
                ""
            );
            if (!success) revert TransferFailed();
        }
    }

    /**
     * @dev Updates a bid before the commit deadline.
     * @param _urlHash The URL's hash associated with the bid.
     */
    function updateBid(bytes32 _urlHash) external beforeCommitDeadline {
        Bid storage bid = bids[msg.sender];
        if (bid.version == 0) revert BidDoesNotExist();

        bid.timestamp = block.timestamp;
        bid.urlHash = _urlHash;
        bid.version++;
    }

    /**
     * @dev Reveals a bid only between commit deadline and reveal deadline, returns warranty to the bidder.
     * @param _url The URL associated with the bid.
     */
    function revealBid(
        string memory _url
    ) external afterCommitDeadline beforeRevealDeadline {
        Bid storage bid = bids[msg.sender];
        if (bid.version == 0) revert BidDoesNotExist();
        if (bid.revealed) revert BidAlreadyRevealed();
        if (bytes32(keccak256(abi.encodePacked(_url))) != bid.urlHash)
            revert InvalidUrl();

        bid.url = _url;
        bid.revealed = true;
        validBids++;

        emit BidRevealed(bid);

        (bool success, ) = payable(msg.sender).call{value: warrantyAmount}("");
        if (!success) revert TransferFailed();
    }

    /**
     * @dev Selects the winner of the bid and sets their address.
     * @param _winner The address of the selected winner.
     */
    function choseWinner(
        address _winner
    ) external payable onlyOwner afterRevealDeadline {
        if(!bids[_winner].revealed) revert BidNotRevealed();
        
        winner = _winner;
        emit Winner(name, _winner, ipfsUrl);

        // returns unrevealed warranty amounts to the bid's owner
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        if (!success) revert TransferFailed();
    }

    /**
     * @dev If there are no active valid bids, it cancels the whole tender.
     */
    function cancelBids() public onlyOwner afterRevealDeadline {
        if(validBids > 0) revert ThereAreValidBids();
        emit BidCancelled();

        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        if(!success) revert TransferFailed();
    }

    /**
     * @dev Extends the deadline of the contract.
     * @param _newDeadline The new deadline timestamp.
     */
    function extendCommitDeadline(
        uint128 _newDeadline
    ) public onlyOwner beforeCommitDeadline {
        if(_newDeadline <= commitDeadline) revert InvalidDeadline();
        commitDeadline = _newDeadline;

        emit CommitDeadlineExtended(startBid + _newDeadline);
    }

    /**
     * @dev Extends the deadline of the contract.
     * @param _newDeadline The new deadline timestamp.
     */
    function extendRevealDeadline(
        uint128 _newDeadline
    ) public onlyOwner beforeRevealDeadline {
        if(_newDeadline <= revealDeadline) revert InvalidDeadline();
        revealDeadline = _newDeadline;

        emit RevealDeadlineExtended(startBid + commitDeadline + _newDeadline);
    }

    /**
     * @dev Gets the list of bidders who participated in the bidding process.
     * @return An array containing the list of bids.
     */
    function getBidders()
        public
        view
        afterCommitDeadline
        returns (Bid[] memory)
    {
        Bid[] memory bidList = new Bid[](bidders.length);
        for (uint256 i = 0; i < bidders.length; ) {
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
    function getNumberOfBidders() public view returns (uint256) {
        return bidders.length;
    }

    /**
     * @dev Calculates the total bid cost in ether
     * including bid fee (in usd) and warranty amount (in eth).
     * @return The total bid cost in ether.
     */
    function getBidCost() public view returns (uint256) {
        int256 etherPrice = IVeritrustFactory(factoryContract).getLatestData();
        return uint256(int256(bidFee * 1 ether) / etherPrice) + warrantyAmount;
    }

    receive() external payable {}
}
