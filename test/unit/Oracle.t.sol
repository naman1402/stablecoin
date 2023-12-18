// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {StdCheats} from "../../lib/forge-std/src/StdCheats.sol";
import {Oracle, AggregatorV3Interface} from "../../src/libraries/Oracle.sol";

contract OracleLibTest is StdCheats, Test {
    using Oracle for AggregatorV3Interface;

    MockV3Aggregator public aggregator;
    uint8 public constant DECIMALS = 8;
    int256 public constant INITAL_PRICE = 2000 ether;

    function setUp() public {
        aggregator = new MockV3Aggregator(DECIMALS, INITAL_PRICE);
    }

    function testGetTimeout() public {
        uint256 expectedTimeout = 3 hours;
        assertEq(Oracle.getTimeOut(AggregatorV3Interface(address(aggregator))), expectedTimeout);
    }

    // Foundry Bug - I have to make staleCheckLatestRoundData public
    function testPriceRevertsOnStaleCheck() public {
        vm.warp(block.timestamp + 4 hours + 1 seconds);
        vm.roll(block.number + 1);

        vm.expectRevert(Oracle.staleCheckLatestRounds.selector);
        AggregatorV3Interface(address(aggregator)).staleCheckLatestRounds();
    }

    function testPriceRevertsOnBadAnsweredInRound() public {
        uint80 _roundId = 0;
        int256 _answer = 0;
        uint256 _timestamp = 0;
        uint256 _startedAt = 0;
        aggregator.updateRoundData(_roundId, _answer, _timestamp, _startedAt);

        vm.expectRevert(Oracle.staleCheckLatestRounds.selector);
        AggregatorV3Interface(address(aggregator)).staleCheckLatestRounds();
    }
}
