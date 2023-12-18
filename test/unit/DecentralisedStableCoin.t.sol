// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {DecentralisedStableCoin} from "../../src/DecentralisedStableCoin.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {StdCheats} from "../../lib/forge-std/src/StdCheats.sol";

contract DecentralisedStableCoinTest is StdCheats, Test {
    DecentralisedStableCoin dsc;

    function setUp() public {
        dsc = new DecentralisedStableCoin();
    }

    function testMustMintMoreThanZero() public {
        vm.prank(dsc.owner());
        vm.expectRevert();
        dsc.mint(0, address(this));
    }

    function testMustBurnMoreThanYouHave() public {
        vm.startPrank(dsc.owner());
        dsc.mint(100, address(this));
        vm.expectRevert();
        dsc.burn(101);
        vm.stopPrank();
    }

    function testCantMintToZeroAddress() public {
        vm.startPrank(dsc.owner());
        vm.expectRevert();
        dsc.mint(100, address(0));
        vm.stopPrank();
    }
}
