// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import { LibTreasury } from "./LibTreasury.sol";
import { VotingPowerStorage } from '../storage/VotingPowerStorage.sol';
import { TreasuryStorage } from '../storage/TreasuryStorage.sol';
import { LibTreasury } from './LibTreasury.sol';

import "hardhat/console.sol";

library LibVotingPower {

  function _increaseVotingPower(address voter, uint amount) internal {
    VotingPowerStorage.Layout storage l = VotingPowerStorage.layout();
    VotingPowerStorage.Domain storage d = l.domains[VotingPowerStorage.Type.Treasury];
    // TODO: require msg.sender == operator
    d.votingPower[voter] += amount;
  }

  function _decreaseVotingPower(address voter, uint amount) internal {
    VotingPowerStorage.Layout storage l = VotingPowerStorage.layout();
    VotingPowerStorage.Domain storage d = l.domains[VotingPowerStorage.Type.Treasury];

    // TODO: require msg.sender == operator
    // require(!LibTreasury._hasVotedInActiveProposals(voter), "Cannot unstake until proposal is active");
    d.votingPower[voter] -= amount;
  }

  function _getVoterVotingPower(address voter) internal view returns(uint) {
    VotingPowerStorage.Layout storage l = VotingPowerStorage.layout();
    VotingPowerStorage.Domain storage d = l.domains[VotingPowerStorage.Type.Treasury];
    return d.votingPower[voter];
  }

  function _getTotalAmountOfVotingPower() internal view returns(uint) {
    VotingPowerStorage.Layout storage l = VotingPowerStorage.layout();
    VotingPowerStorage.Domain storage d = l.domains[VotingPowerStorage.Type.Treasury];
    return d.totalAmountOfVotingPower;
  }

  function _getMaxAmountOfVotingPower() internal view returns(uint) {
    VotingPowerStorage.Layout storage l = VotingPowerStorage.layout();
    VotingPowerStorage.Domain storage d = l.domains[VotingPowerStorage.Type.Treasury];
    return d.maxAmountOfVotingPower;
  }


  function _getMinimumQuorum() internal view returns(uint) {
    TreasuryStorage.TreasuryVotingPower storage tvp = LibTreasury._getTreasuryVotingPower();
    uint maxAmountOfVotingPower = _getMaxAmountOfVotingPower();
    return uint(tvp.minimumQuorum) * maxAmountOfVotingPower / uint(tvp.precision);
  }

  function _isQuorum() internal view returns(bool) {
    TreasuryStorage.TreasuryVotingPower storage tvp = LibTreasury._getTreasuryVotingPower();
    uint maxAmountOfVotingPower = _getMaxAmountOfVotingPower();
    uint totalAmountOfVotingPower = _getTotalAmountOfVotingPower();
    return uint(tvp.minimumQuorum) * maxAmountOfVotingPower / uint(tvp.precision) <= totalAmountOfVotingPower;
  }

  function _isEnoughVotingPower(address holder) internal view returns(bool) {
    TreasuryStorage.TreasuryVotingPower storage tvp = LibTreasury._getTreasuryVotingPower();
    uint voterPower = _getVoterVotingPower(holder);
    uint totalAmountOfVotingPower = _getTotalAmountOfVotingPower();
    return voterPower >= (uint(tvp.thresholdForInitiator) * totalAmountOfVotingPower / uint(tvp.precision));
  }

  function _isProposalThresholdReached(uint amountOfVotes) internal view returns(bool) {
    TreasuryStorage.TreasuryVotingPower storage tvp = LibTreasury._getTreasuryVotingPower();
    uint totalAmountOfVotingPower = _getTotalAmountOfVotingPower();
    return amountOfVotes >= (uint(tvp.thresholdForProposal) * totalAmountOfVotingPower / uint(tvp.precision));
  }

}
