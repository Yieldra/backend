// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {YieldUSD} from "../src/YieldUSD.sol";

contract YieldUSDScript is Script {
    YieldUSD public yieldUSD;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        yieldUSD = new YieldUSD(0x6Ac3aB54Dc5019A2e57eCcb214337FF5bbD52897);

        vm.stopBroadcast();
    }
}
