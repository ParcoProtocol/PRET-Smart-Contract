// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ParcoPropertyToken is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Property details
    string public propertyName;
    uint256 public propertyValue;
    uint256 public annualDistributionRate; // percentage (e.g., 9 for 9%)
    address public payoutWallet;
    IERC20 public stablecoin; // USDC recommended

    // Whitelist compliance
    mapping(address => bool) public whitelist;

    // Stay utility
    mapping(address => bool) public stayLocked;
    mapping(address => uint256) public stayLockTimestamp;
    uint256 public constant stayLockPeriod = 365 days;

    // Distribution management
    mapping(address => uint256) public lastClaimed;
    uint256 public constant distributionInterval = 30 days;

    event DistributionClaimed(address indexed user, uint256 amount);
    event StayLocked(address indexed user, uint256 timestamp);
    event WhitelistUpdated(address indexed user, bool status);

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _propertyName,
        uint256 _propertyValue,
        uint256 _annualDistributionRate,
        uint256 _totalSupply,
        address _payoutWallet,
        address _stablecoinAddress
    ) ERC20(_name, _symbol) {
        propertyName = _propertyName;
        propertyValue = _propertyValue;
        annualDistributionRate = _annualDistributionRate;
        payoutWallet = _payoutWallet;
        stablecoin = IERC20(_stablecoinAddress);

        _mint(msg.sender, _totalSupply * (10 ** decimals()));
    }

    modifier onlyWhitelisted(address _user) {
        require(whitelist[_user], "Address not whitelisted");
        _;
    }

    function updateWhitelist(address _user, bool _status) external onlyOwner {
        whitelist[_user] = _status;
        emit WhitelistUpdated(_user, _status);
    }

    function lockForStay() external onlyWhitelisted(msg.sender) {
        require(balanceOf(msg.sender) > 0, "Must hold tokens");
        stayLocked[msg.sender] = true;
        stayLockTimestamp[msg.sender] = block.timestamp;
        emit StayLocked(msg.sender, block.timestamp);
    }

    function claimDistribution() external nonReentrant onlyWhitelisted(msg.sender) {
        require(
            !stayLocked[msg.sender] || block.timestamp > stayLockTimestamp[msg.sender] + stayLockPeriod,
            "Tokens locked for stay"
        );

        uint256 lastClaim = lastClaimed[msg.sender];
        if (lastClaim == 0) {
            lastClaim = block.timestamp - distributionInterval;
        }

        require(block.timestamp >= lastClaim + distributionInterval, "Already claimed this period");

        uint256 userShare = balanceOf(msg.sender);
        uint256 monthlyDistribution = (propertyValue * annualDistributionRate * distributionInterval * userShare) /
            (100 * totalSupply() * 365 days);

        lastClaimed[msg.sender] = block.timestamp;

        stablecoin.safeTransferFrom(payoutWallet, msg.sender, monthlyDistribution);

        emit DistributionClaimed(msg.sender, monthlyDistribution);
    }

    // Override ERC20 transfer to include whitelist checks
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override onlyWhitelisted(to) {
        if (from != address(0)) {
            require(whitelist[from], "Sender not whitelisted");
        }
        super._beforeTokenTransfer(from, to, amount);
    }

    // Owner can withdraw accidentally sent tokens
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
    }

    // Accept ETH sent directly to contract (for any future flexibility)
    receive() external payable {}

    function withdrawETH() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}


