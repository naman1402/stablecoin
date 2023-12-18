// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MockV3Aggregator} from "./MockV3Aggregator.sol";

contract MockMoreDebtDSC is ERC20Burnable, Ownable {
    error DecentralisedStableCoin__AmountmustBeMoreThanZero();
    error DecentralisedStableCoin__BurnAmountExceedsBalance();
    error DecentralisedStableCoin__NotZeroAddress();

    address _mockAggregator;

    constructor(address mockAggregator) ERC20("DecentralisedStableCoin", "DSC") {
        _mockAggregator = mockAggregator;
    }

    function burn(uint256 _amount) public override onlyOwner {
        MockV3Aggregator(_mockAggregator).updateAnswer(0);
        uint256 balance = balanceOf(msg.sender);

        if (_amount <= 0) {
            revert DecentralisedStableCoin__AmountmustBeMoreThanZero();
        }
        if (_amount > balance) {
            revert DecentralisedStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralisedStableCoin__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert DecentralisedStableCoin__AmountmustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}
