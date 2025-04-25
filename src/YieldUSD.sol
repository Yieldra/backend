// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ITestUSDC {
    function claimFaucet() external;
}

contract YieldUSD is ERC20, Ownable {
    IERC20 public stableToken; // e.g., DAI or USDC
    uint256 public apy = 500; // 5% APY (in basis points)
    uint256 constant SECONDS_IN_YEAR = 31536000;
    
    // For hackathon demo purposes - can be adjusted for quicker yield accrual
    uint256 public yieldAmplifier = 1; // Set to higher values for accelerated demos

    struct Deposit {
        uint256 amount;
        uint256 timestamp;
    }

    mapping(address => Deposit) public deposits;

    constructor(address _stableToken) ERC20("YieldUSD", "yUSD") Ownable(msg.sender) {
        stableToken = IERC20(_stableToken);
    }

    function deposit(uint256 _amount) external {
        require(_amount > 0, "Amount > 0");

        stableToken.transferFrom(msg.sender, address(this), _amount);

        if (deposits[msg.sender].amount > 0) {
            _mintYield(msg.sender);
        }

        deposits[msg.sender].amount += _amount;
        deposits[msg.sender].timestamp = block.timestamp;

        _mint(msg.sender, _amount); // mint 1:1 yUSD
    }

    function _mintYield(address _user) internal {
        Deposit storage dep = deposits[_user];
        uint256 timeDiff = block.timestamp - dep.timestamp;
        uint256 yield = (dep.amount * apy * timeDiff * yieldAmplifier) / (10000 * SECONDS_IN_YEAR);

        if (yield > 0) {
            _mint(_user, yield); // Mint yield as yUSD
        }

        dep.timestamp = block.timestamp;
    }

    function withdraw() external {
        Deposit memory dep = deposits[msg.sender];
        require(dep.amount > 0, "No deposit");

        _mintYield(msg.sender); // mint pending yield

        _burn(msg.sender, dep.amount); // burn yUSD

        delete deposits[msg.sender];

        stableToken.transfer(msg.sender, dep.amount);
    }

    function earned(address _user) external view returns (uint256) {
        Deposit memory dep = deposits[_user];
        if (dep.amount == 0) return 0;
        uint256 timeDiff = block.timestamp - dep.timestamp;
        return (dep.amount * apy * timeDiff * yieldAmplifier) / (10000 * SECONDS_IN_YEAR);
    }
    
    // New function to allow users to claim USDC from the faucet through this contract
    function claimUSDCFaucet() external {
        ITestUSDC(address(stableToken)).claimFaucet();
    }
    
    // For hackathon demo purposes - allows adjusting APY and amplifier
    function setYieldParameters(uint256 _apy, uint256 _amplifier) external onlyOwner {
        apy = _apy;
        yieldAmplifier = _amplifier;
    }
    
    // Emergency fund function for hackathon demo - fund contract with yields
    function fundYieldReserves(uint256 _amount) external {
        stableToken.transferFrom(msg.sender, address(this), _amount);
    }
}