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

    // private because there is a function to get the value protected by a modifier that checks the end of vote
    uint256 private winningProposalId;
    WorkflowStatus public voteStatus;
    // private because electors are registrerd on votersList. unauthorized persons cannot see the votersList. getters are protected by modifiers
    mapping(address => Voter) private votersList;
    Proposal[] private proposals;

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
        // admin is not votersList by default. just an admin
        voteStatus = WorkflowStatus.RegisteringVoters;
    }

    /* 
*******************************
        modifiers
*******************************
*/

    modifier onlyRegistered() {
        require(votersList[msg.sender].isRegistered, "You are not registered");
        _;
    }

    modifier onlyRegisteredAddress(address _address) {
        require(
            votersList[_address].isRegistered,
            "this address is not registered"
        );
        _;
    }

    modifier checkWorkflowStatus(WorkflowStatus _status) {
        string
            memory message = "This is not the right period. You should be on: ";
        require(
            _status == voteStatus,
            string.concat(message, _getVoteStatusString(_status))
        );
        _;
    }

    modifier checkWorkflowStatusBeforeChange(WorkflowStatus _status) {
        string
            memory message = "You can't change the status if you're not in: ";
        require(
            _status == voteStatus,
            string.concat(message, _getVoteStatusString(_status))
        );
        _;
    }

    /* 
*******************************
        getters
*******************************
*/
    function getProposal(uint256 _id)
        external
        view
        onlyRegistered
        returns (Proposal memory)
    {
        return proposals[_id];
    }

    function getWinner()
        external
        view
        checkWorkflowStatus(WorkflowStatus.VotesTallied)
        returns (uint256)
    {
        return winningProposalId;
    }

    function getWinnerDetails()
        external
        view
        checkWorkflowStatus(WorkflowStatus.VotesTallied)
        returns (Proposal memory)
    {
        return proposals[winningProposalId];
    }

    function getVoterDetails(address _address)
        external
        view
        onlyRegistered
        onlyRegisteredAddress(_address)
        returns (Voter memory)
    {
        return votersList[_address];
    }

    /* 
*******************************
        Voters management
*******************************
*/

    function authorise(address _address)
        external
        onlyOwner
        checkWorkflowStatus(WorkflowStatus.RegisteringVoters)
    {
        require(
            !votersList[_address].isRegistered,
            "Address is already registered"
        );
        votersList[_address].isRegistered = true;
        emit VoterRegistered(_address);
    }

    function unAuthorise(address _address)
        external
        onlyOwner
        checkWorkflowStatus(WorkflowStatus.RegisteringVoters)
    {
        require(votersList[_address].isRegistered, "Address is not registered");
        votersList[_address].isRegistered = false;
        emit VoterUnRegistered(_address);
    }

    /*
********************************
        Workflow status Management
********************************
*/

    function startProposals()
        external
        onlyOwner
        checkWorkflowStatusBeforeChange(WorkflowStatus.RegisteringVoters)
    {
        voteStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(
            WorkflowStatus.RegisteringVoters,
            WorkflowStatus.ProposalsRegistrationStarted
        );
    }

    function endProposals()
        external
        onlyOwner
        checkWorkflowStatusBeforeChange(
            WorkflowStatus.ProposalsRegistrationStarted
        )
    {
        voteStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(
            WorkflowStatus.ProposalsRegistrationStarted,
            WorkflowStatus.ProposalsRegistrationEnded
        );
    }

    function startVotes()
        external
        onlyOwner
        checkWorkflowStatusBeforeChange(
            WorkflowStatus.ProposalsRegistrationEnded
        )
    {
        voteStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(
            WorkflowStatus.ProposalsRegistrationEnded,
            WorkflowStatus.VotingSessionStarted
        );
    }

    function endVotes()
        external
        onlyOwner
        checkWorkflowStatusBeforeChange(WorkflowStatus.VotingSessionStarted)
    {
        voteStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(
            WorkflowStatus.VotingSessionStarted,
            WorkflowStatus.VotingSessionEnded
        );
    }

    function countVotes()
        external
        onlyOwner
        checkWorkflowStatusBeforeChange(WorkflowStatus.VotingSessionEnded)
    {
        //calculate winning vote
        _countingVotes();

        voteStatus = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(
            WorkflowStatus.VotingSessionEnded,
            WorkflowStatus.VotesTallied
        );
    }

    function retrieveWorkflowStatus() external view returns (string memory) {
        return _getVoteStatusString(voteStatus);
    }

    function _getVoteStatusString(WorkflowStatus _status)
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
    Vote Feature
*****************
*/

    function sendProposal(string memory _proposal)
        external
        onlyRegistered
        checkWorkflowStatus(WorkflowStatus.ProposalsRegistrationStarted)
    {
        require(
            keccak256(abi.encode(_proposal)) != keccak256(abi.encode("")),
            "Proposal can't be empty"
        );
        proposals.push(Proposal(_proposal, 0));
        emit ProposalRegistered(proposals.length - 1); // we count proposal 0, 1, 2 to make it easier
    }

    function vote(uint256 _proposalId)
        external
        onlyRegistered
        checkWorkflowStatus(WorkflowStatus.VotingSessionStarted)
    {
        require(!votersList[msg.sender].hasVoted, "You have already voted");
        require(
            _proposalId >= 0 && (proposals.length - 1) >= _proposalId,
            "The proposalId doesn't exist"
        );
        votersList[msg.sender].hasVoted = true;
        votersList[msg.sender].votedProposalId = _proposalId;
        proposals[_proposalId].voteCount++;
        emit Voted(msg.sender, _proposalId);
    }

    function _countingVotes()
        internal
        onlyOwner
        checkWorkflowStatus(WorkflowStatus.VotingSessionEnded)
    {
        uint256 winner = 0;
        for (uint256 i = 1; i < proposals.length; i++) {
            //start at 1 because 0 is our initial winner
            if (proposals[i].voteCount > proposals[winner].voteCount) {
                winner = i;
            }
        }
        winningProposalId = winner;
        emit winningProposal(winningProposalId);
    }
}
