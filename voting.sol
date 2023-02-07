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
    Proposal[] private proposals;

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

    function getWinner() public view returns (uint256) {
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

    function sendProposal(string memory _proposal) public isRegistered {
        require(
            WorkflowStatus.ProposalsRegistrationStarted == voteStatus,
            "This is not the proposal period...."
        );
        proposals.push(Proposal(_proposal, 0));
        emit ProposalRegistered(proposals.length - 1);
        //passer par MAPPING ?
    }
}
