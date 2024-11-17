// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {console2} from "../lib/forge-std/src/console2.sol";

contract OllieCoin is ERC20, Ownable {
    struct Checkpoint {
        uint256 period;
        uint256 balance;
    }
    // State variables

    mapping(address => uint256) private lastClaimedPeriod;
    mapping(address => Checkpoint[]) private userCheckpoints;
    // Add total supply checkpoints
    Checkpoint[] private totalSupplyCheckpoints;
    mapping(uint256 => IERC20) public periodRewardTokens;
    uint256 public currentPeriod;
    mapping(uint256 => uint256) public distributionAmounts;

    // Events
    event RewardsDistributed(uint256 indexed period, address indexed rewardToken, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount, uint256 period);

    // Custom errors
    error InvalidAmount();
    error TransferFailed();
    error NoDistributionsYet();

    constructor(string memory name, string memory symbol) ERC20(name, symbol) Ownable(msg.sender) {}

    /// @notice Mint new tokens
    /// @param to The address to mint tokens to
    /// @param amount The amount of tokens to mint
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    /// @notice Get the balance of an address at a specific period
    /// @param user The address to query
    /// @param period The period to query
    function getBalanceAtPeriod(address user, uint256 period) public view returns (uint256) {
        Checkpoint[] memory checkpoints = userCheckpoints[user];

        if (checkpoints.length == 0) return 0;

        // Binary search for the last checkpoint before or at the period
        uint256 low = 0;
        uint256 high = checkpoints.length - 1;

        while (low < high) {
            uint256 mid = (low + high + 1) / 2;
            if (checkpoints[mid].period <= period) {
                low = mid;
            } else {
                high = mid - 1;
            }
        }
        return checkpoints[low].period <= period ? checkpoints[low].balance : 0;
    }

    function totalSupplyAt(uint256 period) public view returns (uint256) {
        if (totalSupplyCheckpoints.length == 0) return 0;

        // Binary search for the last checkpoint before or at the period
        uint256 low = 0;
        uint256 high = totalSupplyCheckpoints.length - 1;

        while (low < high) {
            uint256 mid = (low + high + 1) / 2;
            if (totalSupplyCheckpoints[mid].period <= period) {
                low = mid;
            } else {
                high = mid - 1;
            }
        }

        return totalSupplyCheckpoints[low].period <= period ?
            totalSupplyCheckpoints[low].balance : 0;
    }

    /// @notice Distribute rewards to users and increment the period
    /// @dev This function is O(1) since it only stores the reward token and period and transfers the tokens
    /// @param token The reward token to distribute
    /// @param amount The amount of tokens to distribute

    function distribute(ERC20 token, uint256 amount) external onlyOwner {
        if (amount == 0) revert InvalidAmount();
        currentPeriod++;
        periodRewardTokens[currentPeriod] = token;
        distributionAmounts[currentPeriod] = amount;  // Store distribution amount

        bool success = token.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        emit RewardsDistributed(currentPeriod, address(token), amount);
    }

    /// @notice Claim rewards for the caller, note that all rewards will be claimed
    function claim() external {
        if (currentPeriod == 0) revert NoDistributionsYet();

        uint256 userLastClaimed = lastClaimedPeriod[msg.sender];
        lastClaimedPeriod[msg.sender] = currentPeriod;
        for (uint256 period = userLastClaimed + 1; period <= currentPeriod; period++) {
            uint256 balance = getBalanceAtPeriod(msg.sender, period - 1);
            if (balance > 0) {
                // Get total supply for the period because we want to distribute proportionally to the total supply
                uint256 totalSupplyAtPeriod = totalSupplyAt(period - 1);
                uint256 rewardAmount = (balance * distributionAmounts[period]) / totalSupplyAtPeriod;
                IERC20 rewardToken = periodRewardTokens[period];
                bool success = rewardToken.transfer(msg.sender, rewardAmount);
                if (!success) revert TransferFailed();
                emit RewardsClaimed(msg.sender, rewardAmount, period);
            }
        }
    }

    ///////////////////////////// Internal functions /////////////////////////////
    /// @dev Hook that is called before any transfer of tokens
    /// @param from The address to transfer from
    /// @param to The address to transfer to
    /// @param value The amount of tokens to transfer
    function _update(address from, address to, uint256 value) internal virtual override {
        super._update(from, to, value);
        // Create checkpoints for addresses involved in transfer
        if (from != address(0)) {
            _writeCheckpoint(from, balanceOf(from));
        }
        if (to != address(0)) {
            _writeCheckpoint(to, balanceOf(to));
        }
        // Update total supply checkpoint
        _writeTotalSupplyCheckpoint(totalSupply());
    }

    /// @dev Write a checkpoint for a user
    /// @param user The address to write a checkpoint for
    /// @param balance The balance to checkpoint
    function _writeCheckpoint(address user, uint256 balance) internal {
        Checkpoint[] storage checkpoints = userCheckpoints[user];
        checkpoints.push(Checkpoint({period: currentPeriod, balance: balance}));
    }

    function _writeTotalSupplyCheckpoint(uint256 supply) internal {
        totalSupplyCheckpoints.push(Checkpoint({
            period: currentPeriod,
            balance: supply
        }));
    }
}
