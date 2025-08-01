
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./CamuVerify.sol";
import "./CamuToken.sol";

interface ITreasury {
    function requestWithdrawal(address payable to, uint256 amount) external returns (uint256);
    function balance() external view returns (uint256); // Optional: Add this to Treasury if needed
}

contract CammunityDAO is Ownable {
    CamuVerify public camuVerify;
    CamuToken public camuToken;
    ITreasury public treasury;

    uint256 public proposalCount;
    uint256 public lastResetMonth;
    uint256 public monthlySpent;

    enum ProposalType { TEXT, FUNDING, TERMINATION }

    struct Proposal {
        uint256 id;
        string description;
        ProposalType proposalType;
        address payable target;
        uint256 amount;
        uint256 verifiedVotes;
        uint256 tokenVotes;
        uint256 voteStart;
        bool stage1Passed;
        bool executed;
        mapping(address => bool) verifiedVoted;
        mapping(address => bool) tokenVoted;
    }

    mapping(uint256 => Proposal) public proposals;

    event NewProposal(uint256 id, string description, ProposalType proposalType);
    event ProposalExecuted(uint256 id);

    constructor(address _camuVerify, address _camuToken, address _treasury) Ownable(msg.sender) {
        camuVerify = CamuVerify(_camuVerify);
        camuToken = CamuToken(_camuToken);
        treasury = ITreasury(_treasury);
        lastResetMonth = block.timestamp / 30 days;
    }

    function createProposal(string memory _description, ProposalType _type, address payable _target, uint256 _amount) external onlyOwner {
        Proposal storage newProposal = proposals[proposalCount];
        newProposal.id = proposalCount;
        newProposal.description = _description;
        newProposal.proposalType = _type;
        newProposal.target = _target;
        newProposal.amount = _amount;
        newProposal.voteStart = block.timestamp;

        emit NewProposal(proposalCount, _description, _type);
        proposalCount++;
    }

    function voteStage1(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.verifiedVoted[msg.sender], "Already voted");
        require(camuVerify.members(msg.sender).verified, "Not verified");

        proposal.verifiedVotes++;
        proposal.verifiedVoted[msg.sender] = true;

        if (proposal.verifiedVotes >= 3) {
            proposal.stage1Passed = true;
        }
    }

    function voteStage2(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.stage1Passed, "Stage 1 not passed");
        require(!proposal.tokenVoted[msg.sender], "Already voted");

        uint256 weight = camuToken.balanceOf(msg.sender);
        require(weight > 0, "No voting power");

        proposal.tokenVotes += weight;
        proposal.tokenVoted[msg.sender] = true;
    }

    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.stage1Passed, "Stage 1 not passed");
        require(!proposal.executed, "Already executed");

        uint256 totalVotes = camuToken.totalSupply();
        uint256 quorum = (proposal.tokenVotes * 100) / totalVotes;

        // Monthly spending cap logic
        if (proposal.proposalType == ProposalType.FUNDING) {
            uint256 currentMonth = block.timestamp / 30 days;
            if (currentMonth > lastResetMonth) {
                lastResetMonth = currentMonth;
                monthlySpent = 0;
            }

            uint256 treasuryBalance = address(treasury).balance;
            uint256 maxMonthlySpend = (treasuryBalance * 15) / 100;

            if (proposal.amount + monthlySpent > maxMonthlySpend) {
                require(quorum >= 67, "Special quorum required for excess budget");
            }

            monthlySpent += proposal.amount;
            treasury.requestWithdrawal(proposal.target, proposal.amount);
        }

        // Fork/termination safeguard
        if (proposal.proposalType == ProposalType.TERMINATION) {
            require(quorum >= 67, "Termination quorum not met");
            require(proposal.tokenVotes >= (totalVotes * 75) / 100, "Termination approval too low");
            require(block.timestamp >= proposal.voteStart + 7 days, "Delay not met");
        }

        proposal.executed = true;
        emit ProposalExecuted(proposalId);
    }
}
