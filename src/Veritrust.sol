// SPDX-License-Identifier: UNLICENCED
pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

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

    mapping(address bidder => Bid bidData) private bids;
    address[] private bidders;

    event BidSet(address tender, address bidder);
    event BidRevealed(Bid bid);
    event Winner(string name, address winner, string ipfsUrl);
    event CommitDeadlineExtended(uint256 newDeadline);
    event RevealDeadlineExtended(uint256 newDeadline);
    event BidCancelled();

    modifier beforeCommitDeadline() {
        require(
            block.timestamp < startBid + commitDeadline,
            "Commit deadline has passed"
        );
        _;
    }

    modifier afterCommitDeadline() {
        require(
            block.timestamp >= startBid + commitDeadline,
            "Wait until commit deadline"
        );
        _;
    }

    modifier beforeRevealDeadline() {
        require(
            block.timestamp < startBid + commitDeadline + revealDeadline,
            "Reveal deadline has passed"
        );
        _;
    }

    modifier afterRevealDeadline() {
        require(
            block.timestamp >= startBid + commitDeadline + revealDeadline,
            "Wait until reveal deadline"
        );
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
        require(
            _commitDeadline > 1 days,
            "Commit deadline must be be greater than 1 day"
        );
        require(
            _revealDeadline > 1 days,
            "Reveal deadline must be greater than 1 day"
        );
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
        require(bidders.length < 101, "Up to 100 bidders");
        uint256 bidCost = getBidCost();
        require(msg.value >= bidCost, "Insufficient bid fee");

        Bid storage bid = bids[msg.sender];
        require(bid.version == 0, "Bid already exists");

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
        require(success, "Fee transfer fail");

        if (msg.value > bidCost) {
            (success, ) = payable(msg.sender).call{value: msg.value - bidCost}(
                ""
            );
            require(success, "return excess transfer fail");
        }
    }

    /**
     * @dev Updates a bid before the commit deadline.
     * @param _urlHash The URL's hash associated with the bid.
     */
    function updateBid(bytes32 _urlHash) external beforeCommitDeadline {
        Bid storage bid = bids[msg.sender];
        require(bid.version > 0, "Bid doesn't exist");

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
        require(bid.version > 0, "Bid doesnt exist");
        require(bid.revealed == false, "Bid already revealed");
        require(bytes32(keccak256(abi.encodePacked(_url))) == bid.urlHash);
        bid.url = _url;
        bid.revealed = true;
        validBids++;

        emit BidRevealed(bid);

        (bool success, ) = payable(msg.sender).call{value: warrantyAmount}("");
        require(success, "Warranty transfer failed");
    }

    /**
     * @dev Selects the winner of the bid and sets their address.
     * @param _winner The address of the selected winner.
     */
    function choseWinner(
        address _winner
    ) external payable onlyOwner afterRevealDeadline {
        require(bids[_winner].revealed == true, "Bid not revealed");

        winner = _winner;

        emit Winner(name, _winner, ipfsUrl);

        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success, "Transfer failed");
    }

    /**
     * @dev If there are no active valid bids, it cancels the whole tender.
     */
    function cancelBids() public onlyOwner afterRevealDeadline {
        require(validBids == 0, "There are valid bids");

        emit BidCancelled();

        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success, "Transfer failed");
    }

    /**
     * @dev Extends the deadline of the contract.
     * @param _newDeadline The new deadline timestamp.
     */
    function extendCommitDeadline(
        uint128 _newDeadline
    ) public onlyOwner beforeCommitDeadline {
        require(
            _newDeadline > commitDeadline,
            "Deadlines can only be extended"
        );
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
        require(
            _newDeadline > revealDeadline,
            "Deadlines can only be extended"
        );
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
