// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {ERC20Burnable, ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title DecentralisedStableCoin
 * @author Naman
 * Collateral: Crypto (ETH & BTC)
 * Minting: Algorithmic
 * Relative Stability: Pegged to USD / INR
 *
 *
 * => this contract is meant to be controlled by DSCEngine. This is just the ERC20 implementation of our stablecoin system.
 */

contract DecentralisedStableCoin is ERC20Burnable, Ownable {
    error DecentralisedStableCoin_MustbeMoreThanZero();
    error DecentralisedStableCoin_BurnAmountHigherThanBalance();
    error DecentralisedStableCoin_AddressIsZero();

    constructor() ERC20("DecentralisedStableCoin", "INRC") {}

    function burn(uint256 _amount) public override onlyOwner {
        // msg.sender will be DSCEngine in this case
        uint256 balance = balanceOf(msg.sender);

        if (_amount <= 0) {
            revert DecentralisedStableCoin_MustbeMoreThanZero();
        }
        if (balance < _amount) {
            revert DecentralisedStableCoin_BurnAmountHigherThanBalance();
        }

        super.burn(_amount);
        // super = use burn function from the parent class which is ERC20Burnable here
    }

    function mint(uint256 _amount, address _to) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralisedStableCoin_AddressIsZero();
        }
        if (_amount <= 0) {
            revert DecentralisedStableCoin_MustbeMoreThanZero();
        }
        // calling the mint function directly , we are not using SUPER because here we are not overriding any function
        _mint(_to, _amount);
        return true;
    }
}
