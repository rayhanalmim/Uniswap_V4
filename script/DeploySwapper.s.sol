// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Swapper} from "../src/Swapper.sol";

contract DeploySwapper is Script {
    // These addresses should be updated based on the target network
    address private constant UNIVERSAL_ROUTER_SEPOLIA =
        0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD; // Replace with actual Sepolia address
    address private constant POOL_MANAGER_SEPOLIA =
        0x64255ed21366DB43d89736EE48928b890A84E2Cb; // Replace with actual Sepolia address
    address private constant PERMIT2_SEPOLIA =
        0x000000000022D473030F116dDEE9F6B43aC78BA3; // Replace with actual Sepolia address

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy Swapper contract
        Swapper swapper = new Swapper(
            UNIVERSAL_ROUTER_SEPOLIA,
            POOL_MANAGER_SEPOLIA,
            PERMIT2_SEPOLIA
        );

        vm.stopBroadcast();

        // Log the deployed contract address
        console.log("Swapper deployed at:", address(swapper));
    }
}
