// SPDX-License-Identifier: UNLICENCED
pragma solidity 0.8.19;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract OracleMock is AggregatorV3Interface {
  function decimals() external view returns (uint8) {
    return 8;
  }

  function description() external view returns (string memory) {
    return "";
  }

  function version() external view returns (uint256) {
    return 1;
  }

  function getRoundData(uint80 _roundId) external view returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    ) {

    }

  function latestRoundData() external view returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    ) {
        answer = 177800000000;
    }
}