// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {DecentralisedStableCoin} from "../../src/DecentralisedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";


contract Handler is Test {
    DSCEngine engine;
    DecentralisedStableCoin dsc;
    IERC20 wbtc;
    IERC20 weth;

    constructor(DecentralisedStableCoin _dsc, DSCEngine _engine) {
        engine = _engine;
        dsc = _dsc;

        address[] memory colalteralTokens = engine.getCollateralTokens();
        weth = IERC20(colalteralTokens[0]);
        wbtc = IERC20(colalteralTokens[1]);
    }

    function depositCollateral (uint256 collateralSeed, uint256 amountCollateral) public {
        // random address, also reverts on amount=0
        IERC20 collateral = _getCollateralFromSeed(collateralSeed);
        engine.depositCollateral(amountCollateral, address(collateral));
    }

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (IERC20) {

        if(collateralSeed % 2 == 0) {
            return weth;
        }

        return wbtc;
    }


}