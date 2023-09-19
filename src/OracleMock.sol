// SPDX-License-Identifier: UNLICENCED
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract OracleMock is AggregatorV3Interface {
    function decimals() external pure returns (uint8) {
        return 8;
    }

    function description() external pure returns (string memory) {
        return "";
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    { }

    function latestRoundData() external pure returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
        answer = 177_800_000_000;
        roundId = 0;
        startedAt = 0;
        updatedAt = 0;
        answeredInRound = 0;
    }
}
