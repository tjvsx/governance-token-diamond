// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library ERC20TokenStorage {           
    
    struct Layout {  
        mapping(address => uint) balances;      
        mapping(address => mapping(address => uint)) approved;        
        uint96 totalSupplyCap;      
        uint96 totalSupply;                
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256('habitat.token.diamond.storage');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    } 
}