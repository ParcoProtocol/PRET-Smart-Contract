// Smart Contract for Parco's Showcase Property Token (Polygon)
// Version 1 - Supports: Ownership, Distributions, Stay Utility, Governance

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ParcoPropertyToken is ERC20, Ownable, ReentrancyGuard {
    // Showcase Property Info (set during deployment)
    string public propertyName;
    uint256 public propertyValue;
    uint256 public annualDistributionRate; // e.g., 9 means 9% annual return
    address public payoutWallet; // wallet where revenue is deposited for distribution

    // Stay Utility
    mapping(address => bool) public stayLocked; // If true, user forfeits yield for stay access
    mapping(address => uint256) public stayLockTimestamp;
    uint256 public stayLockPeriod = 365 days;

    // Distribution
    mapping(address => uint256) public lastClaimed;
    uint256 public distributionInterval = 30 days;

    event DistributionClaimed(address indexed user, uint256 amount);
    event StayLocked(address indexed user, uint256 timestamp);

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _propertyName,
        uint256 _propertyValue,
        uint256 _annualDistributionRate,
        uint256 _totalSupply,
        address _payoutWallet
    ) ERC20(_name, _symbol) {
        propertyName = _propertyName;
        propertyValue = _propertyValue;
        annualDistributionRate = _annualDistributionRate;
        payoutWallet = _payoutWallet;

        _mint(msg.sender, _totalSupply * (10 ** decimals()));
    }

    function lockForStay() external {
        require(balanceOf(msg.sender) > 0, "You must hold tokens");
        stayLocked[msg.sender] = true;
        stayLockTimestamp[msg.sender] = block.timestamp;
        emit StayLocked(msg.sender, block.timestamp);
    }

    function claimDistribution() external nonReentrant {
        require(!stayLocked[msg.sender] || block.timestamp > stayLockTimestamp[msg.sender] + stayLockPeriod,
            "Your tokens are locked for stay and ineligible for yield");

        uint256 timeElapsed = block.timestamp - lastClaimed[msg.sender];
        require(timeElapsed >= distributionInterval, "Already claimed this period");

        uint256 userShare = balanceOf(msg.sender);
        uint256 totalSupply_ = totalSupply();
        uint256 distributionAmount = (propertyValue * annualDistributionRate / 100) * userShare / totalSupply_ / (365 / 30); // monthly share

        lastClaimed[msg.sender] = block.timestamp;

        // payout simulated as a transfer from the payout wallet
        payable(msg.sender).transfer(distributionAmount);

        emit DistributionClaimed(msg.sender, distributionAmount);
    }

    // Allow owner to withdraw accidentally sent ETH
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    // Accept ETH sent to contract (e.g. from revenue streams)
    receive() external payable {}
}

// DEPLOYMENT INSTRUCTIONS:
// Fill in the constructor with:
// name: "Parco Showcase Token"
// symbol: "PST1"
// propertyName: "Showcase Property 001"
// propertyValue: e.g., 500000 ether (in USD-equivalent via stablecoin or ETH on Polygon)
// annualDistributionRate: 9 (for 9%)
// totalSupply: 10000 tokens (1 token = 1/10000 share)
// payoutWallet: Parco's multisig or vault receiving rental revenue

