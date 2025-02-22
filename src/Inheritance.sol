// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

contract Inheritance is KeeperCompatibleInterface {
    uint256 public totalStake;

    struct StakeInfo {
        uint256 balance;
        uint256 lastSignIn;
        address nominee;
        uint256 signInterval;
    }

    mapping(address => StakeInfo) public stakes;
    address[] public users; // Store all users

    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function stake(address _nominee, uint256 _signInterval) public payable {
        require(msg.value > 0, "Stake amount must be greater than zero");

        if (stakes[msg.sender].balance == 0) {
            users.push(msg.sender); // Add new user to tracking list
        }

        stakes[msg.sender].balance += msg.value;
        stakes[msg.sender].lastSignIn = block.timestamp;
        stakes[msg.sender].nominee = _nominee;
        stakes[msg.sender].signInterval = _signInterval;

        totalStake += msg.value;
    }

    function unstake(uint256 amount) public {
        require(stakes[msg.sender].balance >= amount, "Insufficient balance");
        require(
            block.timestamp <=
                stakes[msg.sender].lastSignIn + stakes[msg.sender].signInterval,
            "Unstake period expired"
        );

        stakes[msg.sender].balance -= amount;
        totalStake -= amount;

        payable(msg.sender).transfer(amount);
    }

    function updateSignInterval(uint256 _signInterval) public {
        require(stakes[msg.sender].balance > 0, "No stake found");
        stakes[msg.sender].signInterval = _signInterval;
    }

    function updateNominee(address _nominee) public {
        require(stakes[msg.sender].balance > 0, "No stake found");
        stakes[msg.sender].nominee = _nominee;
    }

    function signIn() public {
        require(stakes[msg.sender].balance > 0, "No stake found");
        stakes[msg.sender].lastSignIn = block.timestamp;
    }

    function checkAndTransferFunds(address user) internal {
        if (
            stakes[user].balance > 0 &&
            block.timestamp >
            stakes[user].lastSignIn + stakes[user].signInterval
        ) {
            uint256 amount = stakes[user].balance;
            stakes[user].balance = 0;
            totalStake -= amount;

            if (stakes[user].nominee != address(0)) {
                payable(stakes[user].nominee).transfer(amount);
            }
        }
    }

    // 1️⃣ Chainlink Keepers will call this function to check if execution is needed
    function checkUpkeep(
        bytes calldata
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        for (uint256 i = 0; i < users.length; i++) {
            if (
                stakes[users[i]].balance > 0 &&
                block.timestamp >
                stakes[users[i]].lastSignIn + stakes[users[i]].signInterval
            ) {
                return (true, abi.encode(users[i]));
            }
        }
        return (false, bytes(""));
    }

    // 2️⃣ If `checkUpkeep` returns true, Keepers execute this function
    function performUpkeep(bytes calldata performData) external override {
        address user = abi.decode(performData, (address));
        checkAndTransferFunds(user);
    }
}
