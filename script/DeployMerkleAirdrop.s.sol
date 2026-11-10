// SPDX-License-Identifier: MIT

pragma solidity ^0.8.35;

import {Script} from "forge-std/Script.sol";
import {BagelToken} from "../src/BagelToken.sol";
import {MerkleAirdrop, IERC20} from "../src/MerkleAirdrop.sol";

contract DeployMerkleAirdrop is Script {

    bytes32 private ROOT = 0xaa5d581231e596618465a56aa0f5870ba6e20785fe436d5bfb82b08662ccc7c4;
    uint256 private AMOUNT_TO_TRANSFER = 4* 25 * 1e18;

    function deployMerkleAirdrop() public returns (MerkleAirdrop, BagelToken) {
        vm.startBroadcast();
        BagelToken token = new BagelToken();
        MerkleAirdrop airdrop = new MerkleAirdrop(ROOT, token);
        token.mint(token.owner(), AMOUNT_TO_TRANSFER);
        //bool transferResult = token.transfer(address(airdrop), AMOUNT_TO_TRANSFER);
        //assertEq(transferResult, true);
        IERC20(token).transfer(address(airdrop), AMOUNT_TO_TRANSFER);
        vm.stopBroadcast();
        return(airdrop, token);
    }

    function run() external returns (MerkleAirdrop, BagelToken) {
        return deployMerkleAirdrop();
    }
}