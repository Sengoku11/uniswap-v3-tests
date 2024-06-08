// SPDX-License-Identifier: MIT
pragma solidity <0.9.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ISwapRouter02 } from "./ISwapRouter02.sol";
import { IERC20 } from "forge-std/src/interfaces/IERC20.sol";

interface IWETH9 is IERC20 {
    function deposit() external payable;
    function withdraw(uint256) external;
}

/**
 * SwapGatekeeper serves as a wallet and a trading venue.
 *
 * It accepts orders from the owner (and in the future from selected wallets at different geos)
 * and executes them.
 *
 * Some balance checks and approvals are designed to be called from the backend to save gas.
 */
contract SwapGatekeeper is Ownable {
    address private immutable ROUTER;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    constructor(address _router) Ownable(msg.sender) {
        ROUTER = _router;
    }

    /**
     * Withdrawing Ethers from the contract is a little more complex, and currently
     * this contract does not use meta transactions (extra work to avoid WETH permit exploit),
     * so it's not necessary to keep eth on the account.
     *
     * Also trading with ETH is not efficient, as it will consume gas on each trade to convert ETH to WETH.
     */
    receive() external payable {
        IWETH9(WETH).deposit{ value: msg.value }();
    }

    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] memory path) public onlyOwner {
        ISwapRouter02(ROUTER).swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: amountOutMin,
            path: path,
            to: address(this)
        });
    }

    function approve(address _token) external onlyOwner {
        IERC20(_token).approve(ROUTER, type(uint256).max);
    }

    function withdraw(address _token) external onlyOwner returns (bool success) {
        IERC20(_token).transfer(owner(), IERC20(_token).balanceOf(address(this)));
        return true;
    }
}
