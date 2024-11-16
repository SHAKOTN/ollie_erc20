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
}
