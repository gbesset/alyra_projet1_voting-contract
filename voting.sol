// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Voting is Ownable {
    //QUESTION mettre les deinitions qq pat et importer !
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

    uint256 private winningProposalId; //private ou pas ? sert a rien..
    WorkflowStatus private voteStatus;
    mapping(address => Voter) private whitelist;
    Proposal[] public proposals;

    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(
        WorkflowStatus previousStatus,
        WorkflowStatus newStatus
    );
    event ProposalRegistered(uint256 proposalId);
    event Voted(address voter, uint256 proposalId);

    event VoterUnRegistered(address voterAddress);

    constructor() {
        //TODO L’administrateur est celui qui va déployer le smart contract.
        voteStatus = WorkflowStatus.RegisteringVoters;
    }

    function getWinner()
        public
        view
        checkWorkflowStatus(WorkflowStatus.VotesTallied)
        returns (uint256)
    {
        return winningProposalId;
    }

    modifier onlyRegistered() {
        require(whitelist[msg.sender].isRegistered, "You are not registered");
        _;
    }

    modifier onlyAddressRegistered(address _address) {
        require(whitelist[_address].isRegistered, "the user is not registered");
        _;
    }

    modifier checkWorkflowStatus(WorkflowStatus _status) {
        //string msg =WorkflowStatus[_status].toString();
        require(_status == voteStatus, "This is not the right period");
        _;
    }

    /* 
*******************************
        Whitelist management
*******************************
*/

    function authorise(address _address) public onlyOwner {
        require(
            !whitelist[_address].isRegistered,
            "Address is already registered"
        );
        whitelist[_address].isRegistered = true;
        emit VoterRegistered(_address);
    }

    function unAuthorise(address _address) public onlyOwner {
        require(whitelist[_address].isRegistered, "Address is not registered");
        whitelist[_address].isRegistered = false;
        emit VoterUnRegistered(_address);
    }

    function isWhitelisted(address _address) public view returns (bool) {
        return whitelist[_address].isRegistered;
    }

    function hasVoted(address _address)
        public
        view
        onlyRegistered
        onlyAddressRegistered(_address)
        returns (bool)
    {
        return whitelist[_address].hasVoted;
    }

    function votedForProposalId(address _address)
        public
        view
        onlyRegistered
        onlyAddressRegistered(_address)
        returns (uint256)
    {
        return whitelist[_address].votedProposalId;
    }

    /*
********************************
        Workflow status Management
********************************
*/

    function startProposals() public onlyOwner {
        require(
            WorkflowStatus.RegisteringVoters == voteStatus,
            "You can't change the status if you're not in RegisteringVoters status"
        );
        voteStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(
            WorkflowStatus.RegisteringVoters,
            WorkflowStatus.ProposalsRegistrationStarted
        );
    }

    function endProposals() public onlyOwner {
        require(
            WorkflowStatus.ProposalsRegistrationStarted == voteStatus,
            "You can't change the status if you're not in ProposalsRegistrationStarted status"
        );
        voteStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(
            WorkflowStatus.ProposalsRegistrationStarted,
            WorkflowStatus.ProposalsRegistrationEnded
        );
    }

    function startVotes() public onlyOwner {
        require(
            WorkflowStatus.ProposalsRegistrationEnded == voteStatus,
            "You can't change the status if you're not in ProposalsRegistrationEnded status"
        );
        voteStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(
            WorkflowStatus.ProposalsRegistrationEnded,
            WorkflowStatus.VotingSessionStarted
        );
    }

    function endVotes() public onlyOwner {
        require(
            WorkflowStatus.VotingSessionStarted == voteStatus,
            "You can't change the status if you're not in VotingSessionStarted status"
        );
        voteStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(
            WorkflowStatus.VotingSessionStarted,
            WorkflowStatus.VotingSessionEnded
        );
    }

    function countVotes() public onlyOwner {
        require(
            WorkflowStatus.VotingSessionEnded == voteStatus,
            "You can't change the status if you're not in VotingSessionEnded status"
        );

        //calculate winning vote
        countingVotes();

        voteStatus = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(
            WorkflowStatus.VotingSessionEnded,
            WorkflowStatus.VotesTallied
        );
    }

    function restartVoteSession() public onlyOwner {
        require(
            WorkflowStatus.VotesTallied == voteStatus,
            "You can't change the status if you're not in VotesTallied status"
        );
        voteStatus = WorkflowStatus.RegisteringVoters;
        emit WorkflowStatusChange(
            WorkflowStatus.VotesTallied,
            WorkflowStatus.RegisteringVoters
        );
    }

    function retrieveWorkflowStatus()
        public
        view
        onlyOwner
        returns (WorkflowStatus)
    {
        return voteStatus;
    }

    /*function retrieveWorkflowStatus2() public view onlyOwner returns (string memory) {
        return WorkflowStatus[voteStatus].toString();
    }*/

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
        proposals.push(Proposal(_proposal, 0));
        emit ProposalRegistered(proposals.length); // not length-1 because we wwant 1, 2,... not 0, 1,...
    }

    function vote(uint256 _proposalId)
        public
        onlyRegistered
        checkWorkflowStatus(WorkflowStatus.VotingSessionStarted)
    {
        require(!whitelist[msg.sender].hasVoted, "You have already voted");
        require(proposals.length >= _proposalId, "The proposal doesn't exist");
        whitelist[msg.sender].hasVoted = true;
        whitelist[msg.sender].votedProposalId = _proposalId;
        proposals[_proposalId - 1].voteCount++; // id-1 because display 1-2 not 0,1..
        emit Voted(msg.sender, _proposalId);
    }

    function countingVotes()
        internal
        onlyOwner
        checkWorkflowStatus(WorkflowStatus.VotingSessionEnded)
    {
        uint256 winner = 0;
        for (uint256 i = 1; i < proposals.length; i++) {
            //start at 1 because 0 is our initial winingproposalId
            if (
                proposals[i].voteCount > proposals[winningProposalId].voteCount
            ) {
                winningProposalId = i;
            }
        }
        winningProposalId = winner + 1; //display +1
    }
}
