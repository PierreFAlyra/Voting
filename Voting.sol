// SPDX-License-Identifier: MIT

pragma solidity >= 0.8.13;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract Voting is Ownable {
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    struct Proposal {
        string description;
        uint voteCount;
    }

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    event VoterRegistered(address voterAddress); 
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);

    mapping(address => Voter) public voters;
    Proposal[] public proposals;
    uint public winningProposalId; 
    WorkflowStatus public workFlowStatus;
    address[] private previousVoters;

    function registerVoters(address[] calldata _voters) external onlyOwner {
        require(
            workFlowStatus==WorkflowStatus.RegisteringVoters ||
             workFlowStatus==WorkflowStatus.VotesTallied,
             "Can't start a new voting session. Finish the previous one.");
        _deleteVoters(previousVoters);
        delete proposals;
        previousVoters = _voters;
        for (uint i=0; i < _voters.length; i++) {
            _register(_voters[i]);
            emit VoterRegistered(_voters[i]);
        }
        emit WorkflowStatusChange(workFlowStatus, workFlowStatus = WorkflowStatus.RegisteringVoters);
    }

   function startProposalsRegistration() external onlyOwner {
        require(
            workFlowStatus == WorkflowStatus.RegisteringVoters,
            "Can't start proposals registration.");
        emit WorkflowStatusChange(workFlowStatus, workFlowStatus = WorkflowStatus.ProposalsRegistrationStarted);
    }

    function propose(string calldata _proposal) external {
        require(workFlowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Proposals registration not started");
        require(_isRegistered(msg.sender), "You are not registered");
        proposals.push(Proposal(_proposal, 0));

        emit ProposalRegistered(proposals.length-1);
    }

    function endProposalsRegistration() external onlyOwner {
        require(
            workFlowStatus == WorkflowStatus.ProposalsRegistrationStarted,
            "Can't end proposals registration.");
        emit WorkflowStatusChange(workFlowStatus, workFlowStatus = WorkflowStatus.ProposalsRegistrationEnded);
    }

    function startVotingSession() external onlyOwner {
        require(
            workFlowStatus == WorkflowStatus.ProposalsRegistrationEnded,
            "Can't start voting session.");
        emit WorkflowStatusChange(workFlowStatus, workFlowStatus = WorkflowStatus.VotingSessionStarted);
    }

    function vote(uint proposalId) external {
        require(workFlowStatus == WorkflowStatus.VotingSessionStarted, "Voting session not started");
        require(_isRegistered(msg.sender), "You are not registered");
        require(!voters[msg.sender].hasVoted, "You can't vote multiple times.");        
        require(proposalId < proposals.length, "The proposal does not exist.");
        _vote(msg.sender, proposalId);
        proposals[proposalId].voteCount++;
        
        emit Voted(msg.sender, proposalId);
    }

    function endVotingSession() external onlyOwner {
        require(
            workFlowStatus == WorkflowStatus.VotingSessionStarted,
            "Can't end voting session.");
        emit WorkflowStatusChange(workFlowStatus, workFlowStatus = WorkflowStatus.VotingSessionEnded);
    }

    function tallyVote() external onlyOwner {
        require(
            workFlowStatus == WorkflowStatus.VotingSessionEnded,
            "Can't tally votes.");

        Proposal memory _winningProposal = Proposal("Empty proposal", 0);
        uint _winningProposalId;
        for (uint i = 0; i < proposals.length; i++) {
            if (proposals[i].voteCount > _winningProposal.voteCount) {
                _winningProposal = proposals[i];
                _winningProposalId = i;
            }
        }
        winningProposalId = _winningProposalId;

        emit WorkflowStatusChange(workFlowStatus, workFlowStatus = WorkflowStatus.VotesTallied);
    }

    function _vote(address _address, uint _votedProposalId) private {
        voters[_address].hasVoted = true;
        voters[_address].votedProposalId = _votedProposalId;
    }       

    function _register(address _address) private {
        require(_address != address(0), "Invalid address.");
        voters[_address].isRegistered = true;
    }

    function _deleteVoters(address[] storage _voters) private {
        for (uint i=0; i < _voters.length; i++)
            _unregister(_voters[i]);
    }

    function _unregister(address _address) private {
        require(_address != address(0), "Invalid address.");
        delete voters[_address];
    }

    function _isRegistered(address _address) private view returns(bool) {
        return voters[_address].isRegistered;
    }    
}
