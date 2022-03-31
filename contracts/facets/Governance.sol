// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import { IERC20 } from '@solidstate/contracts/token/ERC20/IERC20.sol';
import { ERC20TokenStorage } from '../storage/ERC20TokenStorage.sol';
import { GovernanceStorage } from '../storage/GovernanceStorage.sol'; 



contract Governance {
    
    event Propose(address _proposer, address _proposalContract, uint _endTime);
    event Vote(uint indexed _proposalId, address indexed _voter, uint _votes, bool _support);
    event UnVote(uint indexed _proposalId, address indexed _voter, uint _votes, bool _support);     
    event ProposalExecutionSuccessful(uint _proposalId, bool _passed);
    event ProposalExecutionFailed(uint _proposalId, bytes _error);     

    function proposalCount() external view returns (uint) {
        GovernanceStorage.Layout storage gs = GovernanceStorage.layout();  
        return gs.proposalCount;
    }

    function propose(address _proposalContract, uint _endTime) external returns (uint proposalId) {
        uint contractSize;
        assembly { contractSize := extcodesize(_proposalContract) }
        require(contractSize > 0, 'Governance: Proposed contract is empty');
        ERC20TokenStorage.Layout storage ets = ERC20TokenStorage.layout();
        GovernanceStorage.Layout storage gs = GovernanceStorage.layout();       
        // require(_endTime > block.timestamp + (gs.minDuration * 3600), 'Governance: Voting duration must be longer');
        require(_endTime < block.timestamp + (gs.maxDuration * 3600), 'Governance: Voting time must be shorter');
       
        uint proposerBalance = ets.balances[msg.sender];
        uint totalSupply = ets.totalSupply;        
        require(proposerBalance >= (totalSupply / gs.proposalThresholdDivisor), 'Governance: Balance less than proposer threshold');
        proposalId = gs.proposalCount++;
        GovernanceStorage.Proposal storage proposalStorage = gs.proposals[proposalId];
        proposalStorage.proposer = msg.sender;
        proposalStorage.proposalContract = _proposalContract;
        proposalStorage.deadline = uint64(_endTime);
        emit Propose(msg.sender, _proposalContract, _endTime);
        // adding vote
        proposalStorage.votesYes = uint96(proposerBalance);
        proposalStorage.voted[msg.sender] = GovernanceStorage.Voted(uint96(proposerBalance), true);
        gs.votedProposalIds[msg.sender].push(uint24(proposalId));
        emit Vote(proposalId, msg.sender, proposerBalance, true);
    }

    function executeProposal(uint _proposalId) external {
        ERC20TokenStorage.Layout storage ets = ERC20TokenStorage.layout();
        GovernanceStorage.Layout storage gs = GovernanceStorage.layout();   
        GovernanceStorage.Proposal storage proposalStorage = gs.proposals[_proposalId];
        address proposer = proposalStorage.proposer;
        require(proposer != address(0), 'Governance: Proposal does not exist');
        require(block.timestamp > proposalStorage.deadline, 'Governance: Voting hasn\'t ended');        
        require(proposalStorage.executed != true, 'Governance: Proposal has already been executed');
        proposalStorage.executed = true;
        uint totalSupply = ets.totalSupply;
        uint forVotes = proposalStorage.votesYes;
        uint againstVotes = proposalStorage.votesNo;
        bool proposalPassed = forVotes > againstVotes && forVotes > ets.totalSupply / gs.quorumDivisor;
        uint votes = proposalStorage.voted[proposer].votes;        
        if(proposalPassed) {
            address proposalContract = proposalStorage.proposalContract;
            uint contractSize;            
            assembly { contractSize := extcodesize(proposalContract) }
            if(contractSize > 0) {                        
                (bool success, bytes memory error) = proposalContract.delegatecall(abi.encodeWithSignature('execute', _proposalId));                
                if(success) {
                    if(totalSupply < ets.totalSupplyCap) {
                        uint fractionOfTotalSupply = totalSupply / gs.voteAwardCapDivisor;
                        if(votes > fractionOfTotalSupply) {
                            votes = fractionOfTotalSupply;
                        }
                        // 5 percent reward
                        uint proposerAwardDivisor = gs.proposerAwardDivisor;
                        ets.totalSupply += uint96(votes / proposerAwardDivisor);
                        ets.balances[proposer] += votes / proposerAwardDivisor;
                    }
                    emit ProposalExecutionSuccessful(_proposalId, true);
                }
                else {
                    proposalStorage.stuck = true;
                    proposalStorage.executed = false;
                    emit ProposalExecutionFailed(_proposalId, error);                                
                }
            }
            else {
                proposalStorage.stuck = true;
                proposalStorage.executed = false;
                emit ProposalExecutionFailed(_proposalId, bytes('Proposal contract size is 0'));
            }
        }
        else {
            ets.balances[proposer] -= votes;
            emit ProposalExecutionSuccessful(_proposalId, false);
        }                
    }

    enum ProposalStatus { 
        NoProposal,
        PassedAndReadyForExecution, 
        RejectedAndReadyForExecution,
        PassedAndExecutionStuck,
        VotePending,
        Passed,  
        Rejected        
    }

    function proposalStatus(uint _proposalId) public view returns (ProposalStatus status) {
        ERC20TokenStorage.Layout storage ets = ERC20TokenStorage.layout();
        GovernanceStorage.Layout storage gs = GovernanceStorage.layout();    
        GovernanceStorage.Proposal storage proposalStorage = gs.proposals[_proposalId];
        uint endTime = proposalStorage.deadline;
        if(endTime == 0) {
            status = ProposalStatus.NoProposal;
        }
        else if(block.number < endTime) {
            status = ProposalStatus.VotePending;
        }
        else if(proposalStorage.stuck) {
            status = ProposalStatus.PassedAndExecutionStuck;
        }
        else {
            uint forVotes = proposalStorage.votesYes;
            bool passed = forVotes > proposalStorage.votesNo && forVotes > ets.totalSupply / gs.quorumDivisor;
            if(proposalStorage.executed) {
                if(passed) {
                    status = ProposalStatus.Passed;
                }
                else {
                    status = ProposalStatus.Rejected;
                }
            }
            else {
                if(passed) {
                    status = ProposalStatus.PassedAndReadyForExecution;
                }
                else {
                    status = ProposalStatus.RejectedAndReadyForExecution;
                }
            }
        }
    }
    
    struct RetrievedProposal {
        address proposalContract;
        address proposer;
        uint64 endTime;                
        uint96 againstVotes;
        uint96 forVotes;
        ProposalStatus status;
    }

    function proposal(uint _proposalId) external view returns (RetrievedProposal memory retrievedProposal) {
        GovernanceStorage.Layout storage gs = GovernanceStorage.layout();   
        GovernanceStorage.Proposal storage proposalStorage = gs.proposals[_proposalId];
        retrievedProposal = RetrievedProposal({
            proposalContract: proposalStorage.proposalContract,
            proposer: proposalStorage.proposer,
            endTime: proposalStorage.deadline,                   
            againstVotes: proposalStorage.votesNo,
            forVotes: proposalStorage.votesYes,
            status: proposalStatus(_proposalId)
        });        
    }

    function vote(uint _proposalId, bool _support) external {
        ERC20TokenStorage.Layout storage ets = ERC20TokenStorage.layout();
        GovernanceStorage.Layout storage gs = GovernanceStorage.layout();   
        require(_proposalId < gs.proposalCount, 'Governance: _proposalId does not exist');
        GovernanceStorage.Proposal storage proposalStorage = gs.proposals[_proposalId];
        require(block.timestamp < proposalStorage.deadline, 'Governance: Voting ended');
        require(proposalStorage.voted[msg.sender].votes == 0, 'Governance: Already voted');        
        uint balance = ets.balances[msg.sender];
        if(_support) {
            proposalStorage.votesYes += uint96(balance);
        }
        else {
            proposalStorage.votesNo += uint96(balance);
        }
        proposalStorage.voted[msg.sender] = GovernanceStorage.Voted(uint96(balance), _support);
        gs.votedProposalIds[msg.sender].push(uint24(_proposalId));
        emit Vote(_proposalId, msg.sender, balance, _support);        
        uint totalSupply = ets.totalSupply;
        if(totalSupply < ets.totalSupplyCap) {
            // Reward voter with increase in token            
            uint fractionOfTotalSupply = ets.totalSupply / gs.voteAwardCapDivisor;
            if(balance > fractionOfTotalSupply) {
                balance = fractionOfTotalSupply;
            }
            uint voterAwardDivisor = gs.voterAwardDivisor;
            ets.totalSupply += uint96(balance / voterAwardDivisor);
            ets.balances[msg.sender] += balance / voterAwardDivisor;
        }
    }

    function unvote(uint _proposalId) external {
        ERC20TokenStorage.Layout storage ets = ERC20TokenStorage.layout();
        GovernanceStorage.Layout storage gs = GovernanceStorage.layout();   
        require(_proposalId < gs.proposalCount, 'Governance: _proposalId does not exist');
        GovernanceStorage.Proposal storage proposalStorage = gs.proposals[_proposalId];
        require(block.timestamp < proposalStorage.deadline, 'Governance: Voting ended'); 
        require(proposalStorage.proposer != msg.sender, 'Governance: Can\'t unvote your own proposal');       
        uint votes = proposalStorage.voted[msg.sender].votes;
        bool support = proposalStorage.voted[msg.sender].support;
        require(votes > 0, 'Governance: Did not vote');                
        if(support) {
            proposalStorage.votesYes -= uint96(votes);
        }
        else {
            proposalStorage.votesNo -= uint96(votes);
        }
        delete proposalStorage.voted[msg.sender];
        uint24[] storage proposalIds = gs.votedProposalIds[msg.sender];
        uint length = proposalIds.length;
        uint index;
        for(; index < length; index++) {
            if(uint(proposalIds[index]) == _proposalId) {
                break;
            }
        }
        uint lastIndex = length-1;
        if(lastIndex != index) {
            proposalIds[index] = proposalIds[lastIndex];    
        }
        proposalIds.pop();
        emit UnVote(_proposalId, msg.sender, votes, support);
        // Remove voter reward
        uint voterAwardDivisor = gs.voterAwardDivisor;
        ets.totalSupply -= uint96(votes / voterAwardDivisor);
        ets.balances[msg.sender] -= votes / voterAwardDivisor;
    }

}