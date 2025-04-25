// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TestUSDC} from "../src/TestUSDC.sol";

contract TestUSDCScript is Script {
    TestUSDC public testUSDC;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        testUSDC = new TestUSDC();

        vm.stopBroadcast();
    }
}
