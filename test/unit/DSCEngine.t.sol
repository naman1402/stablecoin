// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DecentralisedStableCoin} from "../../src/DecentralisedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {ERC20Mock} from "../../lib/openzeppelin-contracts/contracts/mocks/ERC20Mock.sol";


contract DSEngineTest is Test {
    
    DeployDSC deployer;
    DecentralisedStableCoin dsc;
    DSCEngine engine;
    HelperConfig config;
    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;
    uint256 public deployerKey;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc , engine , config) = deployer.run();
        (ethUsdPriceFeed , btcUsdPriceFeed , weth, wbtc, deployerKey) = config.activeNetworkConfig();
    }

    //////// pricefeed tests ////////////////

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        // 15e18 * 2000/ETH = 30,000e18 
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = engine.getUSDvalue(weth , ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    ///////// depositCollateral tests /////////////

    function testRevertsIfTransferFromFails() public {
        address owner = msg.sender;
        vm.startPrank(owner);

        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__MoreThanZero.selector);
        engine.depositCollateral(0 , weth);
    }



}

