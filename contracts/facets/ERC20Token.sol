// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC20 } from '@solidstate/contracts/token/ERC20/ERC20.sol';
import { IERC20 } from '@solidstate/contracts/token/ERC20/IERC20.sol';
import { ERC20BaseStorage } from '@solidstate/contracts/token/ERC20/base/ERC20BaseStorage.sol';
import { ERC20MetadataStorage } from '@solidstate/contracts/token/ERC20/metadata/ERC20MetadataStorage.sol';
import { MyTokenInit } from "../storage/MyTokenInit.sol"; 
import { ERC20TokenStorage } from '../storage/ERC20TokenStorage.sol';
import { GovernanceStorage } from '../storage/GovernanceStorage.sol'; 

contract ERC20Token is IERC20 {

    using ERC20MetadataStorage for ERC20MetadataStorage.Layout;

    function initMyToken() public {
        ERC20MetadataStorage.Layout storage l = ERC20MetadataStorage.layout();

        MyTokenInit.MyTokenInitStorage storage mti = MyTokenInit.initStorage();

        require(!mti.isInitialized, 'Contract is already initialized!');
        mti.isInitialized = true;

        l.setName("MTK");
        l.setSymbol("MTK");
        l.setDecimals(8);

        _mint(msg.sender, 1000);
    }

    function name() public view virtual returns (string memory) {
        return ERC20MetadataStorage.layout().name;
    }

    function symbol() public view virtual returns (string memory) {
        return ERC20MetadataStorage.layout().symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return ERC20MetadataStorage.layout().decimals;
    }
    
    function totalSupply() external view override returns (uint) {        
        return ERC20TokenStorage.layout().totalSupply;
    }

    function balanceOf(address _owner) external view override returns (uint balance) {
        ERC20TokenStorage.Layout storage gts = ERC20TokenStorage.layout();
        balance = gts.balances[_owner];
    }

    function transfer(address _to, uint _value) external override returns (bool success) {
        _transferFrom(msg.sender, _to, _value);
        success = true;
    }

    function transferFrom(address _from, address _to, uint _value) external override returns (bool success) {
        ERC20TokenStorage.Layout storage gts = ERC20TokenStorage.layout();
        uint allow = gts.approved[_from][msg.sender];
        require(allow >= _value || msg.sender == _from, 'ERC20: Not authorized to transfer');
        _transferFrom(_from, _to, _value);
        if(msg.sender != _from/*  && allow != uint(-1) */) {
            allow -= _value; 
            gts.approved[_from][msg.sender] = allow;
            emit Approval(_from, msg.sender, allow);
        }
        success = true;        
    }

    function _transferFrom(address _from, address _to, uint _value) internal {
        ERC20TokenStorage.Layout storage ets = ERC20TokenStorage.layout();
        GovernanceStorage.Layout storage gs = GovernanceStorage.layout(); 
        uint balance = ets.balances[_from];
        require(_value <= balance, 'ERC20: Balance less than transfer amount');
        ets.balances[_from] = balance - _value;
        ets.balances[_to] += _value;
        emit Transfer(_from, _to, _value);

        uint24[] storage proposalIds = gs.votedProposalIds[_from];
        uint index = proposalIds.length;
        while(index > 0) {
            index--;
            GovernanceStorage.Proposal storage proposalStorage = gs.proposals[proposalIds[index]];
            require(block.timestamp > proposalStorage.deadline, 'ERC20Token: Cannot transfer during vote');
            require(msg.sender != proposalStorage.proposer || proposalStorage.executed, 'ERC20Token: Proposal must execute first.');
            proposalIds.pop();
        }
    }

    function approve(address _spender, uint _value) external override returns (bool success) {
        ERC20TokenStorage.Layout storage gts = ERC20TokenStorage.layout();
        gts.approved[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        success = true;
    }

    function allowance(address _owner, address _spender) external view override returns (uint remaining) {
        ERC20TokenStorage.Layout storage gts = ERC20TokenStorage.layout();
        remaining = gts.approved[_owner][_spender];
    }

    function increaseAllowance(address _spender, uint _value) external returns (bool success) {
        ERC20TokenStorage.Layout storage gts = ERC20TokenStorage.layout();
        uint allow = gts.approved[msg.sender][_spender];
        uint newAllow = allow + _value;
        require(newAllow > allow || _value == 0, 'Integer Overflow');
        gts.approved[msg.sender][_spender] = newAllow;
        emit Approval(msg.sender, _spender, newAllow);
        success = true;
    }

    function decreaseAllowance(address _spender, uint _value) external returns (bool success) {
        ERC20TokenStorage.Layout storage gts = ERC20TokenStorage.layout();
        uint allow = gts.approved[msg.sender][_spender];
        uint newAllow = allow - _value;
        require(newAllow < allow || _value == 0, 'Integer Underflow');
        gts.approved[msg.sender][_spender] = newAllow;
        emit Approval(msg.sender, _spender, newAllow);
        success = true;
    }   

    function _mint(address _to, uint96 _value) internal {
        ERC20TokenStorage.Layout storage gts = ERC20TokenStorage.layout();   
        gts.totalSupply += _value;
        gts.balances[_to] += _value;
    }
}