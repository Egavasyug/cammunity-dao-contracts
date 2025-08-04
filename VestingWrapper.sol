
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVerification {
    function isVerified(address user) external view returns (bool);
}

interface INFTRegistry {
    function hasPostedNFT(address user) external view returns (bool);
}

interface ITokenRegistry {
    function creatorTokenIssued(address user) external view returns (bool);
    function getUniqueHolders(address creator) external view returns (uint256);
}

interface IDAO {
    function hasVoted(address user) external view returns (bool);
}

contract VestingWrapper {
    address public owner;
    uint256 public constant VERIFICATION_FEE = 100 * 1e18; // e.g., 100 tokens

    IVerification public verificationContract;
    INFTRegistry public nftRegistry;
    ITokenRegistry public tokenRegistry;
    IDAO public daoContract;

    mapping(address => uint256) public airdropBalance;
    mapping(address => bool) public hasClaimed;
    mapping(address => bool) public partialUnlocked;

    event PartialUnlockForVerification(address indexed user, uint256 amount);
    event AirdropUnlocked(address indexed user);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    constructor(
        address _verification,
        address _nftRegistry,
        address _tokenRegistry,
        address _daoContract
    ) {
        owner = msg.sender;
        verificationContract = IVerification(_verification);
        nftRegistry = INFTRegistry(_nftRegistry);
        tokenRegistry = ITokenRegistry(_tokenRegistry);
        daoContract = IDAO(_daoContract);
    }

    function unlockForVerification() external {
        require(!verificationContract.isVerified(msg.sender), "Already verified");
        require(airdropBalance[msg.sender] >= VERIFICATION_FEE, "Insufficient balance");
        require(!partialUnlocked[msg.sender], "Already unlocked partial");

        airdropBalance[msg.sender] -= VERIFICATION_FEE;
        partialUnlocked[msg.sender] = true;

        // Forward logic for payment can be added here if needed

        emit PartialUnlockForVerification(msg.sender, VERIFICATION_FEE);
    }

    function checkAllMilestones(address user) public view returns (bool) {
        return (
            verificationContract.isVerified(user) &&
            nftRegistry.hasPostedNFT(user) &&
            tokenRegistry.creatorTokenIssued(user) &&
            tokenRegistry.getUniqueHolders(user) >= 5 &&
            daoContract.hasVoted(user)
        );
    }

    function claimAirdrop() external {
        require(!hasClaimed[msg.sender], "Already claimed");
        require(checkAllMilestones(msg.sender), "Milestones incomplete");

        hasClaimed[msg.sender] = true;

        emit AirdropUnlocked(msg.sender);
        // Token transfer logic should follow here
    }

    function fundAirdrop(address user, uint256 amount) external onlyOwner {
        airdropBalance[user] += amount;
    }
}
