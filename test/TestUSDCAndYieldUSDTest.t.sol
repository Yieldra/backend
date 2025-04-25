// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TestUSDC.sol";
import "../src/YieldUSD.sol";

contract TestUSDCAndYieldUSDTest is Test {
    TestUSDC public usdc;
    YieldUSD public yieldUSD;
    
    address public deployer = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    
    uint256 public constant INITIAL_USDC_SUPPLY = 1000000 * 10**6; // 1M USDC
    uint256 public constant FAUCET_AMOUNT = 1000 * 10**6; // 1000 USDC
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    function setUp() public {
        vm.startPrank(deployer);
        
        // Deploy both contracts
        usdc = new TestUSDC();
        yieldUSD = new YieldUSD(address(usdc));
        
        // Fund YieldUSD contract with some USDC for yields
        usdc.adminMint(deployer, 10000 * 10**6);
        usdc.approve(address(yieldUSD), 10000 * 10**6);
        yieldUSD.fundYieldReserves(10000 * 10**6);
        
        vm.stopPrank();
    }
    
    // ================ TestUSDC Tests ================
    
    function testUSDCInitialSupply() public view {
        assertEq(usdc.totalSupply(), INITIAL_USDC_SUPPLY);
        assertEq(usdc.balanceOf(deployer), INITIAL_USDC_SUPPLY);
    }
    
    function testUSDCDecimals() public view {
        assertEq(usdc.decimals(), 6);
    }
    
    function testUSDCFaucet() public {
        vm.startPrank(alice);
        
        // Alice claims from faucet
        usdc.claimFaucet();
        assertEq(usdc.balanceOf(alice), FAUCET_AMOUNT);
        
        // Alice can't claim again immediately
        vm.expectRevert("Cooldown active: Please wait before claiming again");
        usdc.claimFaucet();
        
        // Fast forward 24 hours + 1 second
        vm.warp(block.timestamp + 24 hours + 1);
        
        // Now Alice can claim again
        usdc.claimFaucet();
        assertEq(usdc.balanceOf(alice), FAUCET_AMOUNT * 2);
        
        vm.stopPrank();
    }
    
    function testAdminMint() public {
        vm.startPrank(deployer);
        usdc.adminMint(bob, 5000 * 10**6);
        assertEq(usdc.balanceOf(bob), 5000 * 10**6);
        vm.stopPrank();
        
        // Non-owner can't mint
        vm.startPrank(alice);
        vm.expectRevert();
        usdc.adminMint(alice, 1000 * 10**6);
        vm.stopPrank();
    }
    
    // ================ YieldUSD Tests ================
    
    function testDeposit() public {
        vm.startPrank(alice);
        
        // Claim USDC first
        usdc.claimFaucet();
        assertEq(usdc.balanceOf(alice), FAUCET_AMOUNT);
        
        // Approve and deposit
        usdc.approve(address(yieldUSD), FAUCET_AMOUNT);
        yieldUSD.deposit(FAUCET_AMOUNT);
        
        // Check balances
        assertEq(usdc.balanceOf(alice), 0);
        assertEq(yieldUSD.balanceOf(alice), FAUCET_AMOUNT);
        
        // Check deposit record
        (uint256 amount, uint256 timestamp) = yieldUSD.deposits(alice);
        assertEq(amount, FAUCET_AMOUNT);
        assertEq(timestamp, block.timestamp);
        
        vm.stopPrank();
    }
    
    function testYieldAccrual() public {
        vm.startPrank(alice);
        
        // Setup: Alice deposits 1000 USDC
        usdc.claimFaucet();
        usdc.approve(address(yieldUSD), FAUCET_AMOUNT);
        yieldUSD.deposit(FAUCET_AMOUNT);
        uint256 initialBalance = yieldUSD.balanceOf(alice);
        
        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);
        
        // Check earned amount
        uint256 expectedYield = (FAUCET_AMOUNT * 500) / 10000; // 5% APY
        assertEq(yieldUSD.earned(alice), expectedYield);
        
        // Make a new deposit to trigger yield minting
        usdc.claimFaucet(); // Get more USDC (after time warp, cooldown is passed)
        usdc.approve(address(yieldUSD), FAUCET_AMOUNT);
        yieldUSD.deposit(FAUCET_AMOUNT);
        
        // Check that yield was minted
        assertEq(yieldUSD.balanceOf(alice), initialBalance + FAUCET_AMOUNT + expectedYield);
        
        vm.stopPrank();
    }
    
    function testWithdraw() public {
        vm.startPrank(alice);
        
        // Setup: Alice deposits 1000 USDC
        usdc.claimFaucet();
        usdc.approve(address(yieldUSD), FAUCET_AMOUNT);
        yieldUSD.deposit(FAUCET_AMOUNT);
        
        // Fast forward 6 months
        vm.warp(block.timestamp + 182.5 days);
        
        // Expected yield after 6 months
        uint256 expectedYield = (FAUCET_AMOUNT * 500 * (182.5 days)) / (10000 * 365 days);
        
        // Withdraw everything
        yieldUSD.withdraw();
        
        // Check balances after withdrawal
        assertEq(usdc.balanceOf(alice), FAUCET_AMOUNT); // Original amount returned
        assertEq(yieldUSD.balanceOf(alice), expectedYield); // Only yield remains
        
        // Check that deposit is cleared
        (uint256 amount, ) = yieldUSD.deposits(alice);
        assertEq(amount, 0);
        
        vm.stopPrank();
    }
    
    function testYieldAmplifier() public {
        // Set yield amplifier to 10x for faster demo
        vm.prank(deployer);
        yieldUSD.setYieldParameters(500, 10);
        
        vm.startPrank(alice);
        
        // Setup: Alice deposits 1000 USDC
        usdc.claimFaucet();
        usdc.approve(address(yieldUSD), FAUCET_AMOUNT);
        yieldUSD.deposit(FAUCET_AMOUNT);
        
        // Fast forward 30 days
        vm.warp(block.timestamp + 30 days);
        
        // Expected yield with 10x amplifier
        uint256 expectedYield = (FAUCET_AMOUNT * 500 * 10 * (30 days)) / (10000 * 365 days);
        assertEq(yieldUSD.earned(alice), expectedYield);
        
        vm.stopPrank();
    }
    
    function testClaimUSDCFaucet() public {
        vm.prank(alice);
        yieldUSD.claimUSDCFaucet();
        
        assertEq(usdc.balanceOf(alice), FAUCET_AMOUNT);
    }
    
    function testMultipleUsers() public {
        // Alice and Bob both deposit and earn yield
        
        // Alice deposits
        vm.startPrank(alice);
        usdc.claimFaucet();
        usdc.approve(address(yieldUSD), FAUCET_AMOUNT);
        yieldUSD.deposit(FAUCET_AMOUNT);
        vm.stopPrank();
        
        // Bob deposits
        vm.startPrank(bob);
        usdc.claimFaucet();
        usdc.approve(address(yieldUSD), FAUCET_AMOUNT);
        yieldUSD.deposit(FAUCET_AMOUNT);
        vm.stopPrank();
        
        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);
        
        // Expected yield is 5% of deposit
        uint256 expectedYield = (FAUCET_AMOUNT * 500) / 10000;
        
        // Verify earned amounts
        assertEq(yieldUSD.earned(alice), expectedYield);
        assertEq(yieldUSD.earned(bob), expectedYield);
        
        // Alice withdraws
        vm.prank(alice);
        yieldUSD.withdraw();
        
        // Verify balances after Alice's withdrawal
        assertEq(usdc.balanceOf(alice), FAUCET_AMOUNT);
        assertEq(yieldUSD.balanceOf(alice), expectedYield);
        
        // Bob's funds remain untouched
        (uint256 bobAmount, ) = yieldUSD.deposits(bob);
        assertEq(bobAmount, FAUCET_AMOUNT);
    }
    
    function testFundYieldReserves() public {
        uint256 initialContractBalance = usdc.balanceOf(address(yieldUSD));
        
        vm.startPrank(deployer);
        usdc.adminMint(deployer, 5000 * 10**6);
        usdc.approve(address(yieldUSD), 5000 * 10**6);
        yieldUSD.fundYieldReserves(5000 * 10**6);
        vm.stopPrank();
        
        assertEq(usdc.balanceOf(address(yieldUSD)), initialContractBalance + 5000 * 10**6);
    }
}