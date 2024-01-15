// SPDX-License-Identifier: UNLICENCED
pragma solidity ^0.8.19;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IArbitrable } from "@kleros/erc-792/contracts/IArbitrable.sol";
import { IArbitrator } from "@kleros/erc-792/contracts/IArbitrator.sol";

interface IVeritrustFactory {
    function getLatestData() external view returns (int256);
}

/**
 * @title Veritrust
 * @dev This contract handles the bidding process and winner selection for a tender.
 */

contract Veritrust is IArbitrable, Ownable {
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
    address public winner;
    mapping(address bidder => Bid bidData) private bids;
    address[] private bidders;
    uint256 private startBid;
    uint256 public validBids;

    address payable private factoryContract;
    uint256 private bidFee;
    uint256 public warrantyAmount;

    //>>>>>>>   Kleros
    IArbitrator public arbitrator;
    uint256 public constant disputePeriod = 3 minutes; //TODO: ver si dejamos esto personalizable y en tal caso implementar los cambios
    Status public status;
    RulingOptions public ruling;
    uint256 constant numberOfRulingOptions = 2; // Notice that option 0 is reserved for RefusedToArbitrate.
    address payable disputeAddress;

    enum Status {
        Initial,
        WinnerChosen,
        Disputed,
        Resolved
    }

    enum RulingOptions {
        RefusedToArbitrate,
        WinnerValid,
        WinnerInvalid
    }
    //<<<<<<<   Kleros

    event BidSet(address tender, address bidder);
    event BidRevealed(Bid bid);
    event Winner(string name, address winner, string ipfsUrl);
    event CommitDeadlineExtended(uint256 newDeadline);
    event RevealDeadlineExtended(uint256 newDeadline);
    event BidCancelled();

    error InvalidStatus();
    error ReleasedTooEarly();
    error NotArbitrator();
    error ReclaimedTooLate();
    error InsufficientPayment(uint256 _available, uint256 _required);
    error InvalidRuling(uint256 _ruling, uint256 _numberOfChoices);
    error NotArbitrable();

    modifier beforeCommitDeadline() {
        require(block.timestamp < startBid + commitDeadline, "Commit deadline has passed");
        _;
    }

    modifier afterCommitDeadline() {
        require(block.timestamp >= startBid + commitDeadline, "Wait until commit deadline");
        _;
    }

    modifier beforeRevealDeadline() {
        require(block.timestamp < startBid + commitDeadline + revealDeadline, "Reveal deadline has passed");
        _;
    }

    modifier afterRevealDeadline() {
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
     * @param _warrantyAmount A warranty amount in eth that stays in the contract until reveal.
     */
    constructor(
        address _owner,
        string memory _name,
        string memory _ipfsUrl,
        uint128 _commitDeadline,
        uint128 _revealDeadline,
        uint256 _bidFee,
        uint256 _warrantyAmount,
        address _arbitrator
    ) {
        require(_commitDeadline > 1 days, "Commit deadline must be be greater than 1 day");
        require(_revealDeadline > 1 days, "Reveal deadline must be greater than 1 day");
        transferOwnership(_owner);
        name = _name;
        ipfsUrl = _ipfsUrl;
        startBid = block.timestamp;
        commitDeadline = _commitDeadline;
        revealDeadline = _revealDeadline;
        factoryContract = payable(msg.sender);
        bidFee = _bidFee;
        warrantyAmount = _warrantyAmount;
        arbitrator = IArbitrator(_arbitrator);

        status = Status.Initial;
    }

    /**
     * @dev Places a bid in the contract.
     * @param _bidderName The name of the bidder.
     * @param _urlHash The hash of the URL associated with the bid.
     */
    function setBid(string memory _bidderName, bytes32 _urlHash) external payable beforeCommitDeadline {
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

        (bool success,) = factoryContract.call{ value: bidCost - warrantyAmount }("");
        require(success, "Fee transfer fail");

        if (msg.value > bidCost) {
            (success,) = payable(msg.sender).call{ value: msg.value - bidCost }("");
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
    function revealBid(string memory _url) external afterCommitDeadline beforeRevealDeadline {
        Bid storage bid = bids[msg.sender];
        require(bid.version > 0, "Bid doesnt exist");
        require(bid.revealed == false, "Bid already revealed");
        require(bytes32(keccak256(abi.encodePacked(_url))) == bid.urlHash);
        bid.url = _url;
        bid.revealed = true;
        validBids++;

        emit BidRevealed(bid);

        (bool success,) = payable(msg.sender).call{ value: warrantyAmount }("");
        require(success, "Warranty transfer failed");
    }

    /**
     * @dev Selects the winner of the bid and sets their address.
     * @param _winner The address of the selected winner.
     */
    function choseWinner(address _winner) external payable onlyOwner afterRevealDeadline {
        require(bids[_winner].revealed == true, "Bid not revealed");
        bool arbitrable = isArbitrable();
        if (arbitrable) {
            //TODO: vamos a exigir el costo exacto de arbitraje cuando se elige al ganador de garantia?
            // Q el costo es fijo o es variable? si varia esto trae problemas.
            uint256 cost = arbitrator.arbitrationCost("");
            if (cost < msg.value) {
                revert InsufficientPayment(msg.value, cost);
            }
        }

        winner = _winner;
        status = Status.WinnerChosen;

        emit Winner(name, _winner, ipfsUrl);

        if (!arbitrable) {
            (bool success,) = payable(msg.sender).call{ value: address(this).balance }("");
            require(success, "Transfer failed");
        }
    }

    /**
     * @dev If there are no active valid bids, it cancels the whole tender.
     */
    function cancelBids() public onlyOwner afterRevealDeadline {
        require(validBids == 0, "There are valid bids");

        emit BidCancelled();

        (bool success,) = payable(msg.sender).call{ value: address(this).balance }("");
        require(success, "Transfer failed");
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

    /**
     * @dev Checks if there is a arbitrator
     */
    function isArbitrable() public view returns (bool) {
        return address(arbitrator) != address(0);
    }

    /**
     * @dev Get de arbitration cost if there is an arbitrator
     * @return Cost of arbitration or 0
     */
    function arbitrationCost() external view returns (uint256) {
        if (!isArbitrable()) {
            return 0;
        }
        return arbitrator.arbitrationCost("");
    }

    /**
     * @dev create a dispute if there is arbitrator
     * and needs to pay the cost of arbitration
     */
    function createDispute() external payable {
        if (!isArbitrable()) {
            revert NotArbitrable();
        }

        if (status != Status.WinnerChosen) {
            revert InvalidStatus();
        }

        uint256 disputeCost = arbitrator.arbitrationCost("");
        if (msg.value < disputeCost) {
            revert InsufficientPayment(msg.value, disputeCost);
        }

        disputeAddress = payable(msg.sender);
        status = Status.Disputed;
        arbitrator.createDispute{ value: disputeCost }(numberOfRulingOptions, "");

        if (msg.value > disputeCost) {
            (bool success,) = payable(msg.sender).call{ value: msg.value - disputeCost }("");
            require(success, "return excess transfer fail");
        }
    }

    /**
     * @dev callback for the arbitrator to set the ruling
     * and process the result
     */
    function rule(uint256 _disputeID, uint256 _ruling) external override {
        if (msg.sender != address(arbitrator)) {
            revert NotArbitrator();
        }
        if (status != Status.Disputed) {
            revert InvalidStatus();
        }

        //TODO: es posible que recibamos RulingOptions.RefusedToArbitrate ?? que hacemos en este caso?
        if (_ruling > numberOfRulingOptions) {
            revert InvalidRuling(_ruling, numberOfRulingOptions);
        }

        status = Status.Resolved;
        ruling = RulingOptions(_ruling);
        emit Ruling(arbitrator, _disputeID, _ruling);

        if (ruling == RulingOptions.WinnerValid) {
            (bool success,) = payable(owner()).call{ value: address(this).balance }("");
            require(success, "Transfer failed");
        } else if (ruling == RulingOptions.WinnerInvalid) {
            //TODO: ver si enviamos el balance restante que puede incluir ofertas
            //      no reveladas o solo reenbolsar el costo de la disputa
            (bool success,) = disputeAddress.call{ value: address(this).balance }("");
            require(success, "Transfer failed");
        }
    }

    /**
     * @dev Release the balance to the owner if no dispute or win it
     */
    function releaseBalance() external onlyOwner {
        if (block.timestamp < startBid + commitDeadline + revealDeadline + disputePeriod) {
            revert ReleasedTooEarly();
        }

        //TODO: confirmar que dejamos este metodo todos los casos y no solo para retirar si no hubo disputa.
        //      Sino cambiarlo para que solo permita llamarlo cuando no hubo disputa despues del periodo de disputa.
        if (status == Status.Disputed || status == Status.Initial) {
            revert InvalidStatus();
        }

        if (status == Status.Resolved && ruling != RulingOptions.WinnerValid) {
            revert InvalidStatus();
        }

        (bool success,) = payable(msg.sender).call{ value: address(this).balance }("");
        require(success, "Transfer failed");
    }

    receive() external payable { }
}
