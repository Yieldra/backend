// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestUSDC is ERC20, Ownable {
    uint256 public constant FAUCET_AMOUNT = 1000 * 10**6; // 1000 USDC (with 6 decimals)
    uint256 public constant FAUCET_COOLDOWN = 24 hours;
    
    mapping(address => uint256) public lastFaucetTime;
    
    constructor() ERC20("Test USDC", "tUSDC") Ownable(msg.sender) {
        // Set decimals to 6 like real USDC
        _mint(msg.sender, 1000000 * 10**6); // Initial supply to deployer
    }
    
    // Override decimals to match real USDC's 6 decimals
    function decimals() public pure override returns (uint8) {
        return 6;
    }
    
    // Allow users to get test USDC from faucet with cooldown
    function claimFaucet() external {
        require(
            block.timestamp >= lastFaucetTime[msg.sender] + FAUCET_COOLDOWN,
            "Cooldown active: Please wait before claiming again"
        );
        
        lastFaucetTime[msg.sender] = block.timestamp;
        _mint(msg.sender, FAUCET_AMOUNT);
    }
    
    // Admin function to mint more tokens if needed
    function adminMint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}