// SPDX-License-Identifier: MIT
pragma solidity <0.9.0;

import { Test } from "forge-std/src/Test.sol";
import { IERC20 } from "forge-std/src/interfaces/IERC20.sol";
import { SwapGatekeeper, IWETH9 } from "../src/SwapGatekeeper.sol";

contract SwapGatekeeperTest is Test {
    uint256 private constant AMOUNT_WETH = 1 * 1e18;
    uint256 private constant AMOUNT_USDC = 50 * 1e6;
    uint256 private constant MAX_UINT = type(uint256).max;
    address private constant UNISWAP_V3_2 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    error OwnableUnauthorizedAccount(address account);

    SwapGatekeeper internal gk;

    function setUp() public virtual {
        vm.createSelectFork({ urlOrAlias: "mainnet", blockNumber: 20_045_158 });

        gk = new SwapGatekeeper(UNISWAP_V3_2);

        IWETH9(WETH).deposit{ value: AMOUNT_WETH }();
    }

    function test_receive() public {
        assertEq(gkBalanceOf(WETH), 0, "Initial WETH balance is not 0");
        (bool success,) = payable(address(gk)).call{ value: AMOUNT_WETH }("");
        assertTrue(success, "Failed to transfer ETH");
        assertEq(gkBalanceOf(WETH), AMOUNT_WETH, "Eth wasn't wrapped to WETH");
    }

    function test_approve() public {
        assertEq(routerAllowanceOf(WETH), 0, "Initial allowance is not 0");
        gk.approve(WETH);
        assertEq(routerAllowanceOf(WETH), MAX_UINT, "Allowance wasn't set up");
    }

    function test_unauthorizedApprove() public {
        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(0)));
        gk.approve(WETH);
    }

    function test_withdraw() public {
        uint256 initialAmount = thisBalanceOf(WETH);

        transferToGk(WETH, AMOUNT_WETH);
        assertEq(thisBalanceOf(WETH) + AMOUNT_WETH, initialAmount, "Wrong amount was transferred");

        gk.approve(WETH);
        gk.withdraw(WETH);
        assertEq(thisBalanceOf(WETH), initialAmount, "Balance before and after should be equal");
    }

    function test_unauthorizedWithdraw() public {
        transferToGk(WETH, AMOUNT_WETH);
        gk.approve(WETH);

        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(0)));
        gk.withdraw(WETH);
    }

    function test_swapExactTokensForTokens() public {
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = USDC;

        transferToGk(WETH, AMOUNT_WETH);
        gk.approve(WETH);

        gk.swapExactTokensForTokens({ amountIn: AMOUNT_WETH, amountOutMin: 0, path: path });
        assertGt(gkBalanceOf(USDC), 0);
    }

    function test_unauthorizedSwapExactTokensForTokens() public {
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = USDC;

        transferToGk(WETH, AMOUNT_WETH);
        gk.approve(WETH);

        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(0)));
        gk.swapExactTokensForTokens({ amountIn: AMOUNT_WETH, amountOutMin: 0, path: path });
    }

    //======================================== shortcut functions ===========================================

    function thisBalanceOf(address _token) internal view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    function gkBalanceOf(address _token) internal view returns (uint256) {
        return IERC20(_token).balanceOf(address(gk));
    }

    function transferToGk(address _token, uint256 _amount) internal returns (bool) {
        return IERC20(_token).transfer(address(gk), _amount);
    }

    function routerAllowanceOf(address _token) public view returns (uint256) {
        return IERC20(_token).allowance(address(gk), UNISWAP_V3_2);
    }
}
