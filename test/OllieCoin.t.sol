// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {OllieCoin} from "../src/OllieCoin.sol";
import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {RewardToken} from "../src/RewardToken.sol";

contract TestOllieCoin is Test {
    address public ollie = address(0x4);
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);

    RewardToken public rewardCoin;
    OllieCoin public ollieCoin;

    function setUp() public {
        vm.startPrank(ollie);
        rewardCoin = new RewardToken("RewardCoin", "REWARD");
        ollieCoin = new OllieCoin("OllieCoin", "OLLIE");
        // Ollie needs approval from RewardToken to distribute rewards
        rewardCoin.approve(address(ollieCoin), type(uint256).max);
        vm.stopPrank();
    }

    function testDistributions() public {
        vm.startPrank(ollie);
        ollieCoin.mint(user1, 100);
        ollieCoin.mint(user2, 100);
        ollieCoin.mint(user3, 100);

        rewardCoin.mint(ollie, 900);

        ollieCoin.distribute(rewardCoin, 300);
        vm.stopPrank();

        vm.startPrank(user1);
        ollieCoin.transfer(user2, 100);
        vm.stopPrank();

        assertEq(rewardCoin.balanceOf(user1), 0);
        assertEq(rewardCoin.balanceOf(user2), 0);
        assertEq(rewardCoin.balanceOf(user3), 0);

        vm.startPrank(ollie);
        ollieCoin.distribute(rewardCoin, 300);
        vm.stopPrank();

        assertEq(rewardCoin.balanceOf(user1), 0);
        assertEq(rewardCoin.balanceOf(user2), 0);
        assertEq(rewardCoin.balanceOf(user3), 0);

        vm.startPrank(user2);
        ollieCoin.transfer(user3, 200);
        ollieCoin.claim();
        vm.stopPrank();

        vm.startPrank(user1);
        ollieCoin.claim();
        vm.stopPrank();

        assertEq(rewardCoin.balanceOf(user1), 100);
        assertEq(rewardCoin.balanceOf(user2), 300);
        assertEq(rewardCoin.balanceOf(user3), 0);

        vm.startPrank(ollie);
        ollieCoin.distribute(rewardCoin, 300);
        vm.stopPrank();

        vm.startPrank(user1);
        ollieCoin.claim();
        vm.stopPrank();

        vm.startPrank(user2);
        ollieCoin.claim();
        vm.stopPrank();

        vm.startPrank(user3);
        ollieCoin.claim();
        vm.stopPrank();

        assertEq(rewardCoin.balanceOf(user1), 100);
        assertEq(rewardCoin.balanceOf(user2), 300);
        assertEq(rewardCoin.balanceOf(user3), 500);

        assertEq(ollieCoin.balanceOf(user1), 0);
        assertEq(ollieCoin.balanceOf(user2), 0);
        assertEq(ollieCoin.balanceOf(user3), 300);
    }

    function testDistributeRewards(uint256 _amount) public {
        _amount = bound(_amount, 100, 100_000_000e18);
        vm.startPrank(ollie);
        rewardCoin.mint(ollie, _amount);
        ollieCoin.distribute(rewardCoin, _amount);
        vm.stopPrank();
        assertEq(ollieCoin.currentPeriod(), 1);
        assertEq(rewardCoin.balanceOf(address(ollieCoin)), _amount);
    }

    /// @dev Test getBalanceAtPeriod function
    function testGetBalanceAtPeriod(uint256 _amount) public {
        _amount = bound(_amount, 100, 100_000_000e18);
        vm.startPrank(ollie);
        ollieCoin.mint(user1, 100);

        rewardCoin.mint(ollie, _amount);

        // Distribute rewards multiple times to bump the period. But for user data it means that user doesn't have any
        // checkpoints, however, get balance of user for period 4 should still return 100
        ollieCoin.distribute(rewardCoin, _amount / 4);
        ollieCoin.distribute(rewardCoin, _amount / 4);
        ollieCoin.distribute(rewardCoin, _amount / 4);
        vm.stopPrank();
        assertEq(ollieCoin.getBalanceAtPeriod(user1, 4), 100);
    }

    /// @dev Same as above but tracking total supply
    function testTotalSupplyAt(uint256 _amount) public {
        _amount = bound(_amount, 100, 100_000_000e18);
        vm.startPrank(ollie);
        ollieCoin.mint(user1, 100);

        rewardCoin.mint(ollie, _amount);

        // Distribute rewards multiple times to bump the period. But for user data it means that user doesn't have any
        // checkpoints, however, get total supply for period 4 should still return 100
        ollieCoin.distribute(rewardCoin, _amount / 4);
        ollieCoin.distribute(rewardCoin, _amount / 4);
        ollieCoin.distribute(rewardCoin, _amount / 4);
        vm.stopPrank();
        assertEq(ollieCoin.totalSupplyAt(4), 100);
    }
}
