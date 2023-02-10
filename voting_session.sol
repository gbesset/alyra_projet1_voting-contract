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
        VoteToCreate,
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
    uint256 public sessionId;
    mapping(uint256 => VoteSession) voteSession;
    //Passé beaucoup de temps a me casser les dents pour mettre ma voterList et Proposals dans ma struc en vain....
    //si meilleur idée que ca (héritage sans doute) je suis preneur. tkx :)
    mapping(uint256 => mapping(address => Voter)) voteSessionVotersList;
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

    /* 
*******************************
        modifiers
*******************************
*/

    modifier onlyRegistered() {
        require(
            voteSessionVotersList[sessionId][msg.sender].isRegistered,
            "You are not registered"
        );
        _;
    }

    modifier onlyRegisteredAddress(address _address) {
        require(
            voteSessionVotersList[sessionId][_address].isRegistered,
            "this address is not registered"
        );
        _;
    }

    modifier checkWorkflowStatus(WorkflowStatus _status) {
        string
            memory message = "This is not the right period. You should be on: ";
        require(
            _status == voteSession[sessionId].voteStatus,
            string.concat(message, _getVoteStatusString(_status))
        );
        _;
    }

    modifier checkWorkflowStatusBeforeChange(WorkflowStatus _status) {
        string
            memory message = "You can't change the status if you're not in: ";
        require(
            _status == voteSession[sessionId].voteStatus,
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
        return voteSessionProposals[sessionId][_id];
    }

    //public to have one called by the contract and by people
    function getWinner()
        public
        view
        checkWorkflowStatus(WorkflowStatus.VotesTallied)
        returns (uint256)
    {
        return voteSession[sessionId].winningProposalId;
    }

    //external because only people
    function getWinnerDetails()
        external
        view
        checkWorkflowStatus(WorkflowStatus.VotesTallied)
        returns (string memory)
    {
        string memory message = string.concat(
            "SessionId: ",
            Strings.toString(sessionId),
            "  Resultat: ",
            voteSessionProposals[sessionId][getWinner() - 1].description
        ); //-1 to get the good one
        return message;
    }

    function getVoterDetails(address _address)
        external
        view
        onlyRegistered
        onlyRegisteredAddress(_address)
        returns (Voter memory)
    {
        return voteSessionVotersList[sessionId][_address];
    }

    /* 
*******************************
        voteSession management
*******************************
*/

    //protected by a modifier when restart a session and by a require when first session
    function _createVoteSession(string memory _name) internal onlyOwner {
        sessionId++;
        voteSession[sessionId].name = _name;
        voteSession[sessionId].winningProposalId = 0;
        voteSession[sessionId].voteStatus = WorkflowStatus.RegisteringVoters;
        voteSession[sessionId].nbElector = 0;
        voteSession[sessionId].nbVotes = 0;
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
            !voteSessionVotersList[sessionId][_address].isRegistered,
            "Address is already registered"
        );
        voteSessionVotersList[sessionId][_address].isRegistered = true;
        voteSession[sessionId].nbElector++;
        emit VoterRegistered(_address);
    }

    function unAuthorise(address _address)
        external
        onlyOwner
        checkWorkflowStatus(WorkflowStatus.RegisteringVoters)
    {
        require(
            voteSessionVotersList[sessionId][_address].isRegistered,
            "Address is not registered"
        );
        voteSessionVotersList[sessionId][_address].isRegistered = false;
        voteSession[sessionId].nbElector--;
        emit VoterUnRegistered(_address);
    }

    /*
********************************
        Workflow status Management
********************************
*/

    function createVoteSession(string memory _name)
        external
        onlyOwner
        checkWorkflowStatus(WorkflowStatus.VoteToCreate)
    {
        require(sessionId == 0, "It's not the first session creation....");
        _createVoteSession(_name);
        emit VoteSessionCreated(_name);
    }

    function startProposals()
        external
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
        external
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
        external
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
        external
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
        external
        onlyOwner
        checkWorkflowStatusBeforeChange(WorkflowStatus.VotingSessionEnded)
    {
        //calculate winning vote
        _countingVotes();

        voteSession[sessionId].voteStatus = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(
            WorkflowStatus.VotingSessionEnded,
            WorkflowStatus.VotesTallied
        );
    }

    function restartVoteSession(string memory _name)
        external
        onlyOwner
        checkWorkflowStatusBeforeChange(WorkflowStatus.VotesTallied)
    {
        _createVoteSession(_name);
        emit VoteSessionCreated(_name);
    }

    function retrieveWorkflowStatus() external view returns (string memory) {
        return
            string.concat(
                "SessionId: ",
                Strings.toString(sessionId),
                "  Period:",
                _getVoteStatusString(voteSession[sessionId].voteStatus)
            );
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
        } else if (_status == WorkflowStatus.VoteToCreate) {
            return "VoteToCreate";
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
        voteSessionProposals[sessionId].push(Proposal(_proposal, 0));
        emit ProposalRegistered(voteSessionProposals[sessionId].length); //this time we count 1, 2, 3
    }

    function vote(uint256 _proposalId)
        external
        onlyRegistered
        checkWorkflowStatus(WorkflowStatus.VotingSessionStarted)
    {
        require(
            !voteSessionVotersList[sessionId][msg.sender].hasVoted,
            "You have already voted"
        );
        require(
            _proposalId > 0 &&
                (voteSessionProposals[sessionId].length) >= _proposalId,
            "The proposalId doesn't exist"
        );
        voteSessionVotersList[sessionId][msg.sender].hasVoted = true;
        voteSessionVotersList[sessionId][msg.sender]
            .votedProposalId = _proposalId;
        voteSessionProposals[sessionId][_proposalId - 1].voteCount++; //we have to -1 to get the good one
        voteSession[sessionId].nbVotes++;
        emit Voted(msg.sender, _proposalId);
    }

    function _countingVotes()
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
        voteSession[sessionId].winningProposalId = winner + 1; //we have to +1 to get the good one
        emit winningProposal(voteSession[sessionId].winningProposalId);
    }
}
