// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

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
        uint256 nbElector;
        uint256 nbVotes;
    }

    // current voting session ID
    uint256 sessionId;
    mapping(uint256 => VoteSession) voteSession;
    //Passé beaucoup de temps a me casser les dents pour mettre ma whiteList et Proposals dans ma struc en vain....
    //si possible et une idée je suis preneur. tkx
    mapping(uint256 => mapping(address => Voter)) voteSessionWhitelist;
    mapping(uint256 => Proposal[]) voteSessionProposals;

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
        //Initialise the first Vote Session
        // Active the period RegisteringVoters  when contract is deployed. No admin function to do it
        // admin is not whitelist by default. just an admin
        sessionId = 0;
        voteSession[sessionId].name = "Initial vote Session";
        voteSession[sessionId].winningProposalId = 0;
        voteSession[sessionId].voteStatus = WorkflowStatus.RegisteringVoters;
        voteSession[sessionId].nbElector = 0;
        voteSession[sessionId].nbVotes = 0;

        //voteSession[sessionId] = VoteSession("Initial vote Session", 0, WorkflowStatus.RegisteringVoters, new Proposal[](0));
    }

    /* 
*******************************
        modifiers
*******************************
*/

    modifier onlyRegistered() {
        require(
            voteSessionWhitelist[sessionId][msg.sender].isRegistered,
            "You are not registered"
        );
        _;
    }

    modifier onlyRegisteredAddress(address _address) {
        require(
            voteSessionWhitelist[sessionId][_address].isRegistered,
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
        sessionId++;
        voteSession[sessionId].name = _name;
        voteSession[sessionId].winningProposalId = 0;
        voteSession[sessionId].voteStatus = WorkflowStatus.RegisteringVoters;
        voteSession[sessionId].nbElector = 0;
        voteSession[sessionId].nbVotes = 0;
    }

    //get sessionId
    //get Proposal

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
            !voteSessionWhitelist[sessionId][_address].isRegistered,
            "Address is already registered"
        );
        voteSessionWhitelist[sessionId][_address].isRegistered = true;
        voteSession[sessionId].nbElector++;
        emit VoterRegistered(_address);
    }

    function unAuthorise(address _address)
        public
        onlyOwner
        checkWorkflowStatus(WorkflowStatus.RegisteringVoters)
    {
        require(
            voteSessionWhitelist[sessionId][_address].isRegistered,
            "Address is not registered"
        );
        voteSessionWhitelist[sessionId][_address].isRegistered = false;
        voteSession[sessionId].nbElector--;
        emit VoterUnRegistered(_address);
    }

    function isWhitelisted(address _address) public view returns (bool) {
        return voteSessionWhitelist[sessionId][_address].isRegistered;
    }

    function hasVoted(address _address)
        public
        view
        onlyRegistered
        onlyRegisteredAddress(_address)
        returns (bool)
    {
        return voteSessionWhitelist[sessionId][_address].hasVoted;
    }

    function votedForProposalId(address _address)
        public
        view
        onlyRegistered
        onlyRegisteredAddress(_address)
        returns (uint256)
    {
        return voteSessionWhitelist[sessionId][_address].votedProposalId;
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
        require(
            voteSession[sessionId].nbElector > 1,
            "Need at least 2 electors to proceed to a vote"
        );
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
        require(
            voteSessionProposals[sessionId].length > 1,
            "Need at least 2 proposals to proceed to a vote"
        );
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
        require(
            (voteSession[sessionId].nbVotes * 2 >=
                voteSession[sessionId].nbElector),
            "Need at least 50% voters to end the vote"
        );
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
        return
            string.concat(
                "SessionId: ",
                Strings.toString(sessionId),
                "  Period:",
                getVoteStatusString(voteSession[sessionId].voteStatus)
            );
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
        voteSessionProposals[sessionId].push(Proposal(_proposal, 0));
        emit ProposalRegistered(voteSessionProposals[sessionId].length - 1); // we count proposal 0, 1, 2 to make it easier
    }

    function vote(uint256 _proposalId)
        public
        onlyRegistered
        checkWorkflowStatus(WorkflowStatus.VotingSessionStarted)
    {
        require(
            !voteSessionWhitelist[sessionId][msg.sender].hasVoted,
            "You have already voted"
        );
        require(
            _proposalId >= 0 &&
                (voteSessionProposals[sessionId].length - 1) >= _proposalId,
            "The proposalId doesn't exist"
        );
        voteSessionWhitelist[sessionId][msg.sender].hasVoted = true;
        voteSessionWhitelist[sessionId][msg.sender]
            .votedProposalId = _proposalId;
        voteSessionProposals[sessionId][_proposalId].voteCount++;
        voteSession[sessionId].nbVotes++;
        emit Voted(msg.sender, _proposalId);
    }

    function countingVotes()
        internal
        onlyOwner
        checkWorkflowStatus(WorkflowStatus.VotingSessionEnded)
    {
        uint256 winner = 0;
        for (uint256 i = 1; i < voteSessionProposals[sessionId].length; i++) {
            //start at 1 because 0 is our initial winner
            if (
                voteSessionProposals[sessionId][i].voteCount >
                voteSessionProposals[sessionId][winner].voteCount
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
        returns (string memory)
    {
        string memory message = string.concat(
            "SessionId: ",
            Strings.toString(sessionId),
            "  Resultat: ",
            voteSessionProposals[sessionId][
                voteSession[sessionId].winningProposalId
            ].description
        );
        return message;
    }
}
