// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/StakeHire.sol";
import "../src/ReputationNFT.sol";
import "../src/Escrow.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy ReputationNFT
        ReputationNFT reputationNFT = new ReputationNFT();
        console.log("ReputationNFT deployed at:", address(reputationNFT));

        // Deploy Escrow
        Escrow escrow = new Escrow();
        console.log("Escrow deployed at:", address(escrow));

        // Deploy StakeHire
        StakeHire stakeHire = new StakeHire(address(reputationNFT));
        console.log("StakeHire deployed at:", address(stakeHire));

        // Set up contract relationships
        reputationNFT.setStakeHireContract(address(stakeHire));
        console.log("ReputationNFT configured with StakeHire address");

        escrow.setStakeHireContract(address(stakeHire));
        console.log("Escrow configured with StakeHire address");

        vm.stopBroadcast();
        
        console.log("=== Deployment Complete ===");
        console.log("StakeHire:", address(stakeHire));
        console.log("ReputationNFT:", address(reputationNFT));
        console.log("Escrow:", address(escrow));
    }
}
