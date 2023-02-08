// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Voting is Ownable {
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint256 votedProposalId;
    }

    struct Proposal {
        string description;
        uint256 voteCount;
    }

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    struct VoteSession {
        string name;
        uint256 winningProposalId;
        WorkflowStatus voteStatus;
        mapping(address => Voter) whitelist;
        Proposal[] proposals;
    }

    // current voting session ID
    uint256 sessionId;
    VoteSession[] voteSession;

    event VoteSessionCreated(string _name);
    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(
        WorkflowStatus previousStatus,
        WorkflowStatus newStatus
    );
    event ProposalRegistered(uint256 proposalId);
    event Voted(address voter, uint256 proposalId);

    event VoterUnRegistered(address voterAddress);
    event winningProposal(uint256 proposalId);

    constructor() {
        // Active the period RegisteringVoters  when contract is deployed. No admin function to do it
        // admin is not whitelist by default. just an admin

        voteSession.push(VoteSession());
        sessionId = 0;
        voteSession[sessionId].voteStatus = WorkflowStatus.RegisteringVoters;
    }

    /* 
*******************************
        modifiers
*******************************
*/

    modifier onlyRegistered() {
        require(
            voteSession[sessionId].whitelist[msg.sender].isRegistered,
            "You are not registered"
        );
        _;
    }

    modifier onlyRegisteredAddress(address _address) {
        require(
            voteSession[sessionId].whitelist[_address].isRegistered,
            "this address is not registered"
        );
        _;
    }

    modifier checkWorkflowStatus(WorkflowStatus _status) {
        string
            memory message = "This is not the right period. You should be on: ";
        require(
            _status == voteSession[sessionId].voteStatus,
            string.concat(message, getVoteStatusString(_status))
        );
        _;
    }

    modifier checkWorkflowStatusBeforeChange(WorkflowStatus _status) {
        string
            memory message = "You can't change the status if you're not in: ";
        require(
            _status == voteSession[sessionId].voteStatus,
            string.concat(message, getVoteStatusString(_status))
        );
        _;
    }

    /* 
*******************************
        voteSession management
*******************************
*/

    function createVoteSession(string memory _name)
        internal
        onlyOwner
        checkWorkflowStatus(WorkflowStatus.VotesTallied)
    {
        voteSession.push(VoteSession(_name));
        sessionId++;
        voteSession[sessionId].voteStatus = WorkflowStatus.RegisteringVoters;
    }

    /* 
*******************************
        Whitelist management
*******************************
*/

    function authorise(address _address)
        public
        onlyOwner
        checkWorkflowStatus(WorkflowStatus.RegisteringVoters)
    {
        require(
            !voteSession[sessionId].whitelist[_address].isRegistered,
            "Address is already registered"
        );
        voteSession[sessionId].whitelist[_address].isRegistered = true;
        emit VoterRegistered(_address);
    }

    function unAuthorise(address _address)
        public
        onlyOwner
        checkWorkflowStatus(WorkflowStatus.RegisteringVoters)
    {
        require(
            voteSession[sessionId].whitelist[_address].isRegistered,
            "Address is not registered"
        );
        voteSession[sessionId].whitelist[_address].isRegistered = false;
        emit VoterUnRegistered(_address);
    }

    function isWhitelisted(address _address) public view returns (bool) {
        return voteSession[sessionId].whitelist[_address].isRegistered;
    }

    function hasVoted(address _address)
        public
        view
        onlyRegistered
        onlyRegisteredAddress(_address)
        returns (bool)
    {
        return voteSession[sessionId].whitelist[_address].hasVoted;
    }

    function votedForProposalId(address _address)
        public
        view
        onlyRegistered
        onlyRegisteredAddress(_address)
        returns (uint256)
    {
        return voteSession[sessionId].whitelist[_address].votedProposalId;
    }

    /*
********************************
        Workflow status Management
********************************
*/

    function startProposals()
        public
        onlyOwner
        checkWorkflowStatusBeforeChange(WorkflowStatus.RegisteringVoters)
    {
        voteSession[sessionId].voteStatus = WorkflowStatus
            .ProposalsRegistrationStarted;
        emit WorkflowStatusChange(
            WorkflowStatus.RegisteringVoters,
            WorkflowStatus.ProposalsRegistrationStarted
        );
    }

    function endProposals()
        public
        onlyOwner
        checkWorkflowStatusBeforeChange(
            WorkflowStatus.ProposalsRegistrationStarted
        )
    {
        voteSession[sessionId].voteStatus = WorkflowStatus
            .ProposalsRegistrationEnded;
        emit WorkflowStatusChange(
            WorkflowStatus.ProposalsRegistrationStarted,
            WorkflowStatus.ProposalsRegistrationEnded
        );
    }

    function startVotes()
        public
        onlyOwner
        checkWorkflowStatusBeforeChange(
            WorkflowStatus.ProposalsRegistrationEnded
        )
    {
        voteSession[sessionId].voteStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(
            WorkflowStatus.ProposalsRegistrationEnded,
            WorkflowStatus.VotingSessionStarted
        );
    }

    function endVotes()
        public
        onlyOwner
        checkWorkflowStatusBeforeChange(WorkflowStatus.VotingSessionStarted)
    {
        voteSession[sessionId].voteStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(
            WorkflowStatus.VotingSessionStarted,
            WorkflowStatus.VotingSessionEnded
        );
    }

    function countVotes()
        public
        onlyOwner
        checkWorkflowStatusBeforeChange(WorkflowStatus.VotingSessionEnded)
    {
        //calculate winning vote
        countingVotes();

        voteSession[sessionId].voteStatus = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(
            WorkflowStatus.VotingSessionEnded,
            WorkflowStatus.VotesTallied
        );
    }

    function restartVoteSession(string memory _name)
        public
        onlyOwner
        checkWorkflowStatusBeforeChange(WorkflowStatus.VotesTallied)
    {
        createVoteSession(_name);
        emit VoteSessionCreated(_name);
    }

    function retrieveWorkflowStatus() public view returns (string memory) {
        return getVoteStatusString(voteSession[sessionId].voteStatus);
    }

    function getVoteStatusString(WorkflowStatus _status)
        internal
        pure
        returns (string memory)
    {
        if (_status == WorkflowStatus.RegisteringVoters) {
            return "RegisteringVoters";
        } else if (_status == WorkflowStatus.ProposalsRegistrationStarted) {
            return "ProposalsRegistrationStarted";
        } else if (_status == WorkflowStatus.ProposalsRegistrationEnded) {
            return "ProposalsRegistrationEnded";
        } else if (_status == WorkflowStatus.VotingSessionStarted) {
            return "VotingSessionStarted";
        } else if (_status == WorkflowStatus.VotingSessionEnded) {
            return "VotingSessionEnded";
        } else if (_status == WorkflowStatus.VotesTallied) {
            return "VotesTallied";
        } else {
            return "Unknown status";
        }
    }

    /*
******************
Feature
*****************
*/

    function sendProposal(string memory _proposal)
        public
        onlyRegistered
        checkWorkflowStatus(WorkflowStatus.ProposalsRegistrationStarted)
    {
        voteSession[sessionId].proposals.push(Proposal(_proposal, 0));
        emit ProposalRegistered(voteSession[sessionId].proposals.length - 1); // we count proposal 0, 1, 2 to make it easier
    }

    function vote(uint256 _proposalId)
        public
        onlyRegistered
        checkWorkflowStatus(WorkflowStatus.VotingSessionStarted)
    {
        require(
            !voteSession[sessionId].whitelist[msg.sender].hasVoted,
            "You have already voted"
        );
        require(
            _proposalId >= 0 &&
                (voteSession[sessionId].proposals.length - 1) >= _proposalId,
            "The proposalId doesn't exist"
        );
        voteSession[sessionId].whitelist[msg.sender].hasVoted = true;
        voteSession[sessionId]
            .whitelist[msg.sender]
            .votedProposalId = _proposalId;
        voteSession[sessionId].proposals[_proposalId].voteCount++;
        emit Voted(msg.sender, _proposalId);
    }

    function countingVotes()
        internal
        onlyOwner
        checkWorkflowStatus(WorkflowStatus.VotingSessionEnded)
    {
        uint256 winner = 0;
        for (uint256 i = 1; i < voteSession[sessionId].proposals.length; i++) {
            //start at 1 because 0 is our initial winner
            if (
                voteSession[sessionId].proposals[i].voteCount >
                voteSession[sessionId].proposals[winner].voteCount
            ) {
                winner = i;
            }
        }
        voteSession[sessionId].winningProposalId = winner;
        emit winningProposal(voteSession[sessionId].winningProposalId);
    }

    function getWinner()
        public
        view
        checkWorkflowStatus(WorkflowStatus.VotesTallied)
        returns (uint256)
    {
        return voteSession[sessionId].winningProposalId;
    }

    function getWinnerDetails()
        public
        view
        checkWorkflowStatus(WorkflowStatus.VotesTallied)
        returns (Proposal memory)
    {
        return
            voteSession[sessionId].proposals[
                voteSession[sessionId].winningProposalId
            ];
    }
}
