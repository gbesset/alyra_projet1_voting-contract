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
    mapping(address => Voter) private whitelist;

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
    }

    function getWinner() public view returns (uint256) {
        return winningProposalId;
    }

    modifier isRegistered(address _address) {
        require(whitelist[msg.sender].isRegistered, "You are not registered");
        require(whitelist[_address].isRegistered, "the user is not registered");
        _;
    }

    function authorize(address _address) public onlyOwner {
        require(
            !whitelist[_address].isRegistered,
            "Address is already registered"
        );
        whitelist[_address].isRegistered = true;
        emit VoterRegistered(_address);
    }

    function unregister(address _address) public onlyOwner {
        require(whitelist[_address].isRegistered, "Address is not registered");
        whitelist[_address].isRegistered = false;
        emit VoterUnRegistered(_address);
    }

    function isWhitelisted(address _address) public view returns (bool) {
        //Everybody can know if someone is whitelisted
        return whitelist[_address].isRegistered;
    }

    function hasVoted(address _address)
        public
        view
        isRegistered(_address)
        returns (bool)
    {
        //only whitelisted people  can access that data on registered user
        return whitelist[_address].hasVoted;
    }

    function votedForProposalId(address _address)
        public
        view
        isRegistered(_address)
        returns (uint256)
    {
        //only whitelisted people  can access that data on registered user
        return whitelist[_address].votedProposalId;
    }
}
