// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {DecentralisedStableCoin} from "./DecentralisedStableCoin.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Oracle, AggregatorV3Interface} from "./libraries/Oracle.sol";

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

contract DSCEngine is ReentrancyGuard {
    // =============================================== ERRORS ==============================================================================
    error DSCEngine__MoreThanZero();
    error DSCEngine__TokenAddressLengthMustbeOfSameLengthAsPricefeedLength();
    error DSCEngine__TokenNotAllowed();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorOk();
    error DSCEngine__HealthFactorNotImproved();

    // ================================================= TYPES =================================================================================
    using Oracle for AggregatorV3Interface;

    // =============================================== STATE VARIABLES ==============================================================================

    mapping(address token => address priceFeed) private s_priceFeeds; // tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 collateralAmount)) private s_collateralDeposited; // user - > token - > amount deposited
    mapping(address user => uint256 INRCminted) private s_INRCMinted; // no. of coin minted by an address

    DecentralisedStableCoin private immutable i_inrc; // our stable coin

    address[] private s_collateralTokens; // array of all tokens that can be used as collateral

    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% overcollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATION_BONUS = 10; // this means you get assets at a 10% discount when liquidating
    uint256 private constant MIN_HEALTH_FACTOR = 1;
    uint256 private constant FEED_PRECISION = 1e8;

    // =============================================== EVENTS ==============================================================================

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(address indexed redeemFrom, address indexed redeemTo, address token, uint256 amount);

    // =============================================== MODIFIERS ==============================================================================

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__MoreThanZero();
        }
        _;
    }

    modifier isTokenAllowed(address tokenAddress) {
        if (s_priceFeeds[tokenAddress] == address(0)) {
            revert DSCEngine__TokenNotAllowed();
        }
        _;
    }

    // =============================================== CONSTRUCTOR ==============================================================================

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address inrcAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressLengthMustbeOfSameLengthAsPricefeedLength();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            // if our token address has a priceFeed, it will be mapped
            // we have done this for all the addresses in tokenAddress array
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
        }
        i_inrc = DecentralisedStableCoin(inrcAddress);
    }

    // =============================================== EXTERNAL FUNCTIONS ==============================================================================

    // @param tokenCollateralAddress : the address of token to be deposited as collateral
    // @param amountCollateral : amount of collateral to be deposit
    // @param amountINRCToMint : amount of decentralised sc to be minted

    // @notice this function will deposit your collateral and mint DSC in one transaction

    function depositCollateralAndMintINRC(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountINRCToMint
    ) external {
        depositCollateral(amountCollateral, tokenCollateralAddress);
        mintINRC(amountINRCToMint);
    }

    // @params : amountCollateral : The amount of collateral to deposit (amount of token of wETH or wBTC)
    // @params : tokenCollatoralAddress : The address of the token to deposit as collateral (wETH or wBTC)
    function depositCollateral(uint256 amountCollateral, address tokenCollateralAddress)
        public
        moreThanZero(amountCollateral)
        isTokenAllowed(tokenCollateralAddress)
        nonReentrant
    {
        // does the updating first
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        // then the actual transfer of token ( GOOD PRACTICE )
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function redeemCollateralForINRC(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn)
        external
    {
        burnINRC(amountDscToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
        // redeemCollateral already checks healthFactor
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice follows CEI
     * @param amountINRCToMint = the amount of stablecoin to mint
     * @notice they must have more collateralized value than the minimum threshold to mint the INRC
     */
    function mintINRC(uint256 amountINRCToMint) public moreThanZero(amountINRCToMint) nonReentrant {
        s_INRCMinted[msg.sender] += amountINRCToMint;
        // if they have minted to much stablecoin, ($150 INRC , $100 ETH) we must revert
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_inrc.mint(amountINRCToMint, msg.sender);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    function burnINRC(uint256 amount) public moreThanZero(amount) {
        _burnDsc(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender); // this will never hit, if possible
    }

    /**
     * @param collateral: the erc20 token address of the collateral you're using to make the protocol solvent again
     * This is collateral that you're going to take from the user who is insolvent
     * In return, you have to burn your DSC to pay off their debt, but you don't pay off your own
     *
     * @param user : the user who is insolvent. they have to have a _healthFactor below MIN_HEALTH_FACTOR
     * @param debtToCover : the amount of DSC you want to cover the user's debt
     */
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOk();
        }

        // we want to burn their DSC "debt"
        // and take their collateral

        // if we are covering 100 DSC, we need to $100 of collateral
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);

        // and give them a 10% bonus
        // so we are giving liquidator $110 of WETH for 100 DSC

        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;

        _redeemCollateral(collateral, tokenAmountFromDebtCovered + bonusCollateral, user, msg.sender);
        _burnDsc(debtToCover, user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function getHealthFactor() external view {}

    function getAmountCollateralValue(address user) public view returns (uint256 totaCollateralValueInUsd) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totaCollateralValueInUsd += getUSDvalue(token, amount);
        }

        return totaCollateralValueInUsd;
    }

    function getUSDvalue(address token, uint256 amount) public view returns (uint256) {
        return _getUsdValue(token, amount);
    }

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface pricefeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = pricefeed.latestRoundData();
        return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        (totalDscMinted, collateralValueInUsd) = _getAccountInformation(user);
    }

    function calculateHealthFactor(uint256 totalInrcMinted, uint256 collateralValueInUsd)
        external
        pure
        returns (uint256)
    {
        return _calculateHealthFactor(totalInrcMinted, collateralValueInUsd);
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getDsc() external view returns (address) {
        return address(i_inrc);
    }

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_priceFeeds[token];
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }
    // =============================================== PRIVATE & INTERNAL FUNCTIONS ===========================================================================

    function _getUsdValue(address token, uint256 amount) private view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // 1 ETH = 1000 USD
        // The returned value from Chainlink will be 1000 * 1e8
        // Most USD pairs have 8 decimals, so we will just pretend they all do
        // We want to have everything in terms of WEI, so we add 10 zeros at the end
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function _burnDsc(uint256 amountDscToBurn, address onBehalfOf, address dscFrom) private {
        s_INRCMinted[onBehalfOf] -= amountDscToBurn;

        bool success = i_inrc.transferFrom(dscFrom, address(this), amountDscToBurn);
        // this conditional is hypothetically unreachable
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_inrc.burn(amountDscToBurn);
    }

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalINRCMinted, uint256 collateralValueInUSD)
    {
        totalINRCMinted = s_INRCMinted[user];
        collateralValueInUSD = getAmountCollateralValue(user);
    }

    function _redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral, address from, address to)
        private
    {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(msg.sender, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * returns how close to liquidate a user is
     * if user goes below 1, then they can get liquidate
     */
    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalINRCminted, uint256 collateralValueInUSD) = _getAccountInformation(user);

        // health factor should be more than one because we want more collateral
        // if less then 1 then INRC is more, so it can be liquidated to increase collateral
        // return (collateralValueInUSD / totalINRCminted);

        return _calculateHealthFactor(totalINRCminted, collateralValueInUSD);
    }

    function _calculateHealthFactor(uint256 totalInrcMinted, uint256 collateralValueInUsd)
        internal
        pure
        returns (uint256)
    {
        if (totalInrcMinted == 0) return type(uint256).max;

        uint256 collateralAdjustForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustForThreshold * PRECISION) / totalInrcMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        // 1. check if health factor (do they have enough collateral ??)
        // 2. Revert if they don't

        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }
}
