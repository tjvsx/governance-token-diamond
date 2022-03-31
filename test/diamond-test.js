const { expect } = require('chai');

const {
  getSelectors,
  FacetCutAction,
  removeSelectors,
  findAddressPositionInFacets
} = require('../scripts/libraries/diamond.js')

const { ethers } = require('hardhat');
const { deployDiamond } = require('../scripts/deploy.js');


describe('Diamond', function () {
  let dao;
  let user1
  let user2;
  let user3;
  let diamond;
  let token;

  describe('Facets', function () {

    before(async function () {
      [dao, user1, user2, user3] = await ethers.getSigners();
    });
  
    beforeEach(async function () {
      // // deploy DiamondCutFacet
      // const DiamondCutFacet = await ethers.getContractFactory('DiamondCutFacet')
      // const diamondCutFacet = await DiamondCutFacet.deploy()
      // await diamondCutFacet.deployed()
      // console.log('DiamondCutFacet deployed:', diamondCutFacet.address)

      //deploy diamond contract
      const DiamondFactory = await ethers.getContractFactory('Diamond');
      diamond = await DiamondFactory.deploy(dao.address);
      await diamond.deployed();

      //deploy uninitialized governance contract
      token = await ethers.getContractAt('ERC20Token', diamond.address)

      //declare facets to be cut
      // const facetCuts = [
      //   {
      //     target: localfacet.address,
      //     action: 0,
      //     selectors: Object.keys(localfacet.interface.functions)
      //     // .filter((fn) => fn != 'supportsInterface(bytes4)') // filter out duplicates
      //     .map((fn) => localfacet.interface.getSighash(fn),
      //     ),
      //   },
      // ];
  
      // //do the cut
      // await diamond
      //   .connect(dao)
      //   .diamondCut(facetCuts, ethers.constants.AddressZero, '0x');

      // mylocalfacet = await ethers.getContractAt('LocalFacet', diamond.address);

    });

    describe('Token', function() {

      it('function calls should return a value', async function() {

        await token.initMyToken();
        expect(await token.decimals()).to.equal(8);

      });
    });
  });
});