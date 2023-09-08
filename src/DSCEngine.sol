// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/**
 * @title DecentralisedStableCoin
 * @author Naman
 * 
 * The system is designed to be as minimal as possible, and have the token maintain a token == 1 INR peg
 * Properties:
 * - Exogenous Collateral
 * - Ruppee Pegged
 * - Algorithmically Stable
 * 
 * This is similar to DAI if DAI had no governance and was only backed by wETH and wBTC
 * Our DSC system should always be "overcollateralized". At no point, should the value of all collateral <= value of all the INRC 
 * 
 * @notice This is contract is the core of the INRC system. It handles all the logic for mining and redemming INRC,
 * as well as depositing & withdrawing collateral
 * @notice Loosely based on DAI system
*/

contract DSCEngine {

// =============================================== ERRORS ============================================================================== 
    error DSCEngine__MoreThanZero();
    error DSCEngine__TokenAddressLengthMustbeOfSameLengthAsPricefeedLength();

// =============================================== STATE VARIABLES ============================================================================== 

    mapping (address token => address priceFeed ) private s_priceFeeds; // tokenToPriceFeed 

// =============================================== MODIFIERS ============================================================================== 

    modifier  moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__MoreThanZero();
        }
        _;
    }

// =============================================== CONSTRUCTOR ============================================================================== 

    constructor ( address[] memory tokenAddresses , address[] memory priceFeedAddresses , address inrcAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressLengthMustbeOfSameLengthAsPricefeedLength();
        }
    }

// =============================================== EXTERNAL FUNCTIONS ============================================================================== 
    function depositCollateralAndMintINRC() external {}

    // @params : amountCollateral : The amount of collateral to deposit (amount of token of wETH or wBTC)
    // @params : tokenCollatoralAddress : The address of the token to deposit as collateral (wETH or wBTC)
    function depositCollateral(uint256 amountCollateral , address tokenCollatoralAddress) external moreThanZero(amountCollateral) {

    }

    function redeemCollateralForINRC() external {}

    function redeemCollateral() external{}

    function mintINRC() external{}

    function burnINRC() external {}

    function liquidate() external {} 

    function getHealthFactor() external view {}
}