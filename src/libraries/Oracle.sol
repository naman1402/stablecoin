// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AggregatorV3Interface} from
    "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title Oracle
 * @author Naman
 * @notice This library is used to check the chainlink oracle for stale data
 * if a price is stale, functions will revert, and render the DSCEngine unusable - this is by design
 * we want the DSCEngine to freeze if prices become stale
 *
 * so if the chainlink network explodes and you have a lot of money locked in the protocol - then BOOOM !!
 */

library Oracle {
    error Oracle__StalePrice();

    uint256 private constant TIMEOUT = 3 hours;

    function staleCheckLatestRounds(AggregatorV3Interface chainlinkFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answerInRound) =
            chainlinkFeed.latestRoundData();

        if (updatedAt == 0 || answerInRound < roundId) {
            revert Oracle__StalePrice();
        }

        uint256 secondsSince = block.timestamp - updatedAt;
        if (secondsSince > TIMEOUT) revert Oracle__StalePrice();

        return (roundId, answer, startedAt, updatedAt, answerInRound);
    }

    function getTimeOut(AggregatorV3Interface /* chainlinkFeed */ ) public pure returns (uint256) {
        return TIMEOUT;
    }
}
