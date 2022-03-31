// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
/******************************************************************************\
* Author: Nick Mudge
*
* Implementation of an ERC20 governance token that can govern itself and a project
* using the Diamond Standard.
/******************************************************************************/

import { LibDiamond } from "./libraries/LibDiamond.sol";
import { IERC165 } from './interfaces/IERC165.sol';
import { IERC173 } from "./interfaces/IERC173.sol";
import { DiamondLoupeFacet } from './facets/diamond/DiamondLoupeFacet.sol';
import { DiamondCutFacet } from './facets/diamond/DiamondCutFacet.sol';
import { IDiamondLoupe } from './interfaces/IDiamondLoupe.sol';
import { IDiamondCut } from "./interfaces/IDiamondCut.sol";
// import { FacetRepository } from "./storage/FacetRepository.sol";

import { ERC20Token } from './facets/ERC20Token.sol';
import { Governance } from './facets/Governance.sol';
import { ERC20TokenStorage } from './storage/ERC20TokenStorage.sol';
import { GovernanceStorage } from './storage/GovernanceStorage.sol'; 

import "hardhat/console.sol";

contract Diamond {
    constructor(address _contractOwner) {
        LibDiamond.setContractOwner(_contractOwner);

        // Create a DiamondLoupeFacet contract which implements the Diamond Loupe interface
        DiamondCutFacet diamondCut = new DiamondCutFacet();
        DiamondLoupeFacet diamondLoupe = new DiamondLoupeFacet();
        ERC20Token erc20Token = new ERC20Token();
        Governance governance = new Governance();

/*         FacetRepository.FacetRepositoryStorage storage frs = FacetRepository.facetRepositoryStorage();
        frs.repo = _facetsRepository; */

        // Add the diamondCut external function from the diamondCutFacet
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](4);
        
        bytes4[] memory cutSelector = new bytes4[](1);
        cutSelector[0] = IDiamondCut.diamondCut.selector;
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondCut), 
            action: IDiamondCut.FacetCutAction.Add, 
            functionSelectors: cutSelector
        });

        bytes4[] memory loupeSelectors = new bytes4[](5);
        loupeSelectors[0] = IDiamondLoupe.facetFunctionSelectors.selector;
        loupeSelectors[1] = IDiamondLoupe.facets.selector;
        loupeSelectors[2] = IDiamondLoupe.facetAddress.selector;
        loupeSelectors[3] = IDiamondLoupe.facetAddresses.selector;
        loupeSelectors[4] = IERC165.supportsInterface.selector;
        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupe), 
            action: IDiamondCut.FacetCutAction.Add, 
            functionSelectors: loupeSelectors
        });

        bytes4[] memory governanceSelectors = new bytes4[](6);
        governanceSelectors[0] = Governance.propose.selector;
        governanceSelectors[1] = Governance.executeProposal.selector;
        governanceSelectors[2] = Governance.proposalStatus.selector;
        governanceSelectors[3] = Governance.proposal.selector;
        governanceSelectors[4] = Governance.vote.selector;
        governanceSelectors[5] = Governance.unvote.selector;
        cut[2] = IDiamondCut.FacetCut({
            facetAddress: address(governance), 
            action: IDiamondCut.FacetCutAction.Add, 
            functionSelectors: governanceSelectors
        });

        bytes4[] memory erc20Selectors = new bytes4[](12);
        erc20Selectors[0] = ERC20Token.name.selector;
        erc20Selectors[1] = ERC20Token.symbol.selector;
        erc20Selectors[2] = ERC20Token.decimals.selector;
        erc20Selectors[3] = ERC20Token.totalSupply.selector;
        erc20Selectors[4] = ERC20Token.balanceOf.selector;
        erc20Selectors[5] = ERC20Token.transfer.selector;
        erc20Selectors[6] = ERC20Token.transferFrom.selector;
        erc20Selectors[7] = ERC20Token.approve.selector;
        erc20Selectors[8] = ERC20Token.allowance.selector;
        erc20Selectors[9] = ERC20Token.increaseAllowance.selector;
        erc20Selectors[10] = ERC20Token.decreaseAllowance.selector;
        erc20Selectors[11] = ERC20Token.initMyToken.selector;
        cut[3] = IDiamondCut.FacetCut({
            facetAddress: address(erc20Token), 
            action: IDiamondCut.FacetCutAction.Add, 
            functionSelectors: erc20Selectors
        });

        LibDiamond.diamondCut(cut, address(0), '');

        // #tj - needs more looking into
        // adding ERC165 data
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[IERC165.supportsInterface.selector] = true;        
        bytes4 interfaceID = IDiamondLoupe.facets.selector ^ IDiamondLoupe.facetFunctionSelectors.selector ^ IDiamondLoupe.facetAddresses.selector ^ IDiamondLoupe.facetAddress.selector;
        ds.supportedInterfaces[interfaceID] = true;

        // declaring storage
        ERC20TokenStorage.Layout storage ets = ERC20TokenStorage.layout();
        GovernanceStorage.Layout storage gs = GovernanceStorage.layout();
        // Set total supply cap. The token supply cannot grow past this.
        ets.totalSupplyCap = 100_000_000e18;
        // Require 5 percent of governance token for votes to pass a proposal
        gs.quorumDivisor = 20;
        // Proposers must own 1 percent of totalSupply to submit a proposal
        gs.proposalThresholdDivisor = 100;
        // Proposers get an additional 5 percent of their balance if their proposal passes
        gs.proposerAwardDivisor = 20;
        // Voters get an additional 1 percent of their balance for voting on a proposal
        gs.voterAwardDivisor = 100;
        // Cap voter and proposer balance used to generate awards at 5 percent of totalSupply
        // This is to help prevent too much inflation
        gs.voteAwardCapDivisor = 20;
        // Proposals must have at least 48 hours of voting time
        // gs.minDuration = 48;
        // Proposals must have no more than 336 hours (14 days) of voting time
        gs.maxDuration = 336;

    }  

    fallback() external payable {
        LibDiamond.DiamondStorage storage ds;
        bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;
        // get diamond storage
        assembly {
            ds.slot := position
        }
        // get facet from function selector
        address facet = address(bytes20(ds.facets[msg.sig]));
        require(facet != address(0), "Diamond: Function does not exist");
        // Execute external function from facet using delegatecall and return any value.
        assembly {
            // copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
            // execute function call using the facet
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            // get any return value
            returndatacopy(0, 0, returndatasize())
            // return any return value or error back to the caller
            switch result
                case 0 {
                    revert(0, returndatasize())
                }
                default {
                    return(0, returndatasize())
                }
        }
    }

    receive() external payable {}
}