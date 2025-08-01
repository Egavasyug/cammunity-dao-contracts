
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICAMC {
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract VestingWrapper {
    address public admin;
    ICAMC public camcToken;

    struct Vesting {
        uint256 totalAllocation;
        uint256 unlocked;
        bool verified;
        bool contentPublished;
        bool hasSubscribers;
        bool hasPromoted;
    }

    mapping(address => Vesting) public vestings;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    event TokensUnlocked(address indexed user, uint256 amount);

    constructor(address _camcToken) {
        admin = msg.sender;
        camcToken = ICAMC(_camcToken);
    }

    function initializeVesting(address user, uint256 totalAmount) external onlyAdmin {
        require(vestings[user].totalAllocation == 0, "Already initialized");
        vestings[user] = Vesting({
            totalAllocation: totalAmount,
            unlocked: 0,
            verified: false,
            contentPublished: false,
            hasSubscribers: false,
            hasPromoted: false
        });
    }

    function unlockByVerification(address user) external onlyAdmin {
        _unlockMilestone(user, 25, "verified");
    }

    function unlockByContent(address user) external onlyAdmin {
        _unlockMilestone(user, 25, "contentPublished");
    }

    function unlockBySubscribers(address user) external onlyAdmin {
        _unlockMilestone(user, 25, "hasSubscribers");
    }

    function unlockByPromotion(address user) external onlyAdmin {
        _unlockMilestone(user, 25, "hasPromoted");
    }

    function _unlockMilestone(address user, uint8 percent, string memory flag) internal {
        Vesting storage v = vestings[user];
        require(v.totalAllocation > 0, "User not initialized");

        if (keccak256(abi.encodePacked(flag)) == keccak256("verified")) {
            require(!v.verified, "Already unlocked");
            v.verified = true;
        } else if (keccak256(abi.encodePacked(flag)) == keccak256("contentPublished")) {
            require(!v.contentPublished, "Already unlocked");
            v.contentPublished = true;
        } else if (keccak256(abi.encodePacked(flag)) == keccak256("hasSubscribers")) {
            require(!v.hasSubscribers, "Already unlocked");
            v.hasSubscribers = true;
        } else if (keccak256(abi.encodePacked(flag)) == keccak256("hasPromoted")) {
            require(!v.hasPromoted, "Already unlocked");
            v.hasPromoted = true;
        }

        uint256 amount = (v.totalAllocation * percent) / 100;
        v.unlocked += amount;
        require(camcToken.transfer(user, amount), "Transfer failed");
        emit TokensUnlocked(user, amount);
    }

    function getUnlockedAmount(address user) external view returns (uint256) {
        return vestings[user].unlocked;
    }
}
