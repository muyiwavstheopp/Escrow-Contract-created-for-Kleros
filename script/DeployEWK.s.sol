// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Script.sol";
import "../src/EscrowWithKleros.sol";

contract DeployEWK is Script {
    function run() external {
        address buyer = 0xeB07648f0f1C390bB836bE8598d43d3DfFa5258a;   // Replace with actual test addresses
        address seller = 0xd90f32D18469Ac91DBc85FD8282047eDb406B312;
        address arbitrator = 0x90992fb4E15ce0C59aEFfb376460Fda4Ee19C879; // KlerosLiquid address on Sepolia or mock

        vm.startBroadcast();
        new EscrowWithKleros{value: 0.002 ether}(buyer, seller, arbitrator);
        vm.stopBroadcast();
    }
}
