// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Escrow
 * @notice Secure escrow contract for handling stake deposits and releases
 */
contract Escrow is ReentrancyGuard, Pausable, Ownable {
    
    // ============ Structs ============
    
    struct Deposit {
        address depositor;
        uint256 amount;
        uint256 releaseTime;
        bool isReleased;
        bool isRefunded;
        address beneficiary;
        DepositType depositType;
    }
    
    enum DepositType {
        CompanyStake,
        ApplicationStake,
        SigningBonus
    }
    
    // ============ State Variables ============
    
    address public stakeHireContract;
    uint256 public nextDepositId = 1;
    uint256 public totalDeposits;
    uint256 public totalReleased;
    uint256 public totalRefunded;
    
    // Emergency withdrawal delay
    uint256 public constant EMERGENCY_DELAY = 90 days;
    
    // Mappings
    mapping(uint256 => Deposit) public deposits;
    mapping(address => uint256[]) public userDeposits;
    mapping(address => uint256) public userBalances;
    
    // ============ Events ============
    
    event DepositCreated(
        uint256 indexed depositId,
        address indexed depositor,
        uint256 amount,
        DepositType depositType
    );
    event DepositReleased(
        uint256 indexed depositId,
        address indexed beneficiary,
        uint256 amount
    );
    event DepositRefunded(
        uint256 indexed depositId,
        address indexed depositor,
        uint256 amount
    );
    event EmergencyWithdrawal(
        address indexed user,
        uint256 amount
    );
    
    // ============ Modifiers ============
    
    modifier onlyStakeHire() {
        require(msg.sender == stakeHireContract, "Only StakeHire contract");
        _;
    }
    
    modifier onlyStakeHireOrOwner() {
        require(
            msg.sender == stakeHireContract || msg.sender == owner(),
            "Unauthorized"
        );
        _;
    }
    
    modifier depositExists(uint256 depositId) {
        require(deposits[depositId].depositor != address(0), "Deposit does not exist");
        _;
    }
    
    // ============ Constructor ============
    
    constructor() {}
    
    // ============ Admin Functions ============
    
    /**
     * @notice Set the StakeHire contract address
     */
    function setStakeHireContract(address _stakeHireContract) external onlyOwner {
        require(_stakeHireContract != address(0), "Invalid address");
        stakeHireContract = _stakeHireContract;
    }
    
    /**
     * @notice Pause the contract in case of emergency
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    // ============ Main Functions ============
    
    /**
     * @notice Create a new escrow deposit
     */
    function createDeposit(
        address depositor,
        address beneficiary,
        uint256 releaseTime,
        DepositType depositType
    ) external payable onlyStakeHire whenNotPaused returns (uint256) {
        require(depositor != address(0), "Invalid depositor");
        require(beneficiary != address(0), "Invalid beneficiary");
        require(msg.value > 0, "Deposit amount must be positive");
        require(releaseTime > block.timestamp, "Release time must be in future");
        
        uint256 depositId = nextDepositId++;
        
        deposits[depositId] = Deposit({
            depositor: depositor,
            amount: msg.value,
            releaseTime: releaseTime,
            isReleased: false,
            isRefunded: false,
            beneficiary: beneficiary,
            depositType: depositType
        });
        
        userDeposits[depositor].push(depositId);
        userBalances[depositor] += msg.value;
        totalDeposits += msg.value;
        
        emit DepositCreated(depositId, depositor, msg.value, depositType);
        
        return depositId;
    }
    
    /**
     * @notice Release funds to beneficiary after release time
     */
    function releaseDeposit(uint256 depositId) 
        external 
        depositExists(depositId)
        whenNotPaused
        nonReentrant
    {
        Deposit storage deposit = deposits[depositId];
        
        require(!deposit.isReleased, "Already released");
        require(!deposit.isRefunded, "Already refunded");
        require(block.timestamp >= deposit.releaseTime, "Release time not reached");
        require(
            msg.sender == deposit.beneficiary || 
            msg.sender == stakeHireContract || 
            msg.sender == owner(),
            "Unauthorized"
        );
        
        deposit.isReleased = true;
        userBalances[deposit.depositor] -= deposit.amount;
        totalReleased += deposit.amount;
        
        (bool success, ) = payable(deposit.beneficiary).call{value: deposit.amount}("");
        require(success, "Transfer failed");
        
        emit DepositReleased(depositId, deposit.beneficiary, deposit.amount);
    }
    
    /**
     * @notice Refund deposit to original depositor
     */
    function refundDeposit(uint256 depositId)
        external
        depositExists(depositId)
        onlyStakeHireOrOwner
        whenNotPaused
        nonReentrant
    {
        Deposit storage deposit = deposits[depositId];
        
        require(!deposit.isReleased, "Already released");
        require(!deposit.isRefunded, "Already refunded");
        
        deposit.isRefunded = true;
        userBalances[deposit.depositor] -= deposit.amount;
        totalRefunded += deposit.amount;
        
        (bool success, ) = payable(deposit.depositor).call{value: deposit.amount}("");
        require(success, "Refund failed");
        
        emit DepositRefunded(depositId, deposit.depositor, deposit.amount);
    }
    
    /**
     * @notice Partial release of deposit
     */
    function partialRelease(
        uint256 depositId,
        uint256 amount,
        address recipient
    )
        external
        depositExists(depositId)
        onlyStakeHire
        whenNotPaused
        nonReentrant
    {
        Deposit storage deposit = deposits[depositId];
        
        require(!deposit.isReleased, "Already released");
        require(!deposit.isRefunded, "Already refunded");
        require(amount <= deposit.amount, "Amount exceeds deposit");
        require(recipient != address(0), "Invalid recipient");
        
        deposit.amount -= amount;
        userBalances[deposit.depositor] -= amount;
        
        if (deposit.amount == 0) {
            deposit.isReleased = true;
        }
        
        totalReleased += amount;
        
        (bool success, ) = payable(recipient).call{value: amount}("");
        require(success, "Transfer failed");
        
        emit DepositReleased(depositId, recipient, amount);
    }
    
    /**
     * @notice Emergency withdrawal for stuck funds
     */
    function emergencyWithdraw() external whenPaused nonReentrant {
        uint256 balance = userBalances[msg.sender];
        require(balance > 0, "No balance to withdraw");
        
        // Find all user deposits that are older than emergency delay
        uint256[] memory userDepositIds = userDeposits[msg.sender];
        uint256 withdrawableAmount = 0;
        
        for (uint256 i = 0; i < userDepositIds.length; i++) {
            Deposit storage deposit = deposits[userDepositIds[i]];
            
            if (!deposit.isReleased && 
                !deposit.isRefunded && 
                deposit.depositor == msg.sender &&
                block.timestamp >= deposit.releaseTime + EMERGENCY_DELAY
            ) {
                withdrawableAmount += deposit.amount;
                deposit.isRefunded = true;
            }
        }
        
        require(withdrawableAmount > 0, "No withdrawable amount");
        
        userBalances[msg.sender] -= withdrawableAmount;
        totalRefunded += withdrawableAmount;
        
        (bool success, ) = payable(msg.sender).call{value: withdrawableAmount}("");
        require(success, "Withdrawal failed");
        
        emit EmergencyWithdrawal(msg.sender, withdrawableAmount);
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get deposit details
     */
    function getDeposit(uint256 depositId) external view returns (Deposit memory) {
        return deposits[depositId];
    }
    
    /**
     * @notice Get all deposits for a user
     */
    function getUserDeposits(address user) external view returns (uint256[] memory) {
        return userDeposits[user];
    }
    
    /**
     * @notice Get user's total balance in escrow
     */
    function getUserBalance(address user) external view returns (uint256) {
        return userBalances[user];
    }
    
    /**
     * @notice Get contract statistics
     */
    function getContractStats() external view returns (
        uint256 _totalDeposits,
        uint256 _totalReleased,
        uint256 _totalRefunded,
        uint256 _currentBalance
    ) {
        return (
            totalDeposits,
            totalReleased,
            totalRefunded,
            address(this).balance
        );
    }
    
    /**
     * @notice Check if deposit can be released
     */
    function canRelease(uint256 depositId) external view returns (bool) {
        Deposit memory deposit = deposits[depositId];
        return (
            deposit.depositor != address(0) &&
            !deposit.isReleased &&
            !deposit.isRefunded &&
            block.timestamp >= deposit.releaseTime
        );
    }
    
    /**
     * @notice Get active deposits count for a user
     */
    function getActiveDepositsCount(address user) external view returns (uint256) {
        uint256[] memory userDepositIds = userDeposits[user];
        uint256 count = 0;
        
        for (uint256 i = 0; i < userDepositIds.length; i++) {
            Deposit memory deposit = deposits[userDepositIds[i]];
            if (!deposit.isReleased && !deposit.isRefunded) {
                count++;
            }
        }
        
        return count;
    }
    
    // ============ Receive Function ============
    
    /**
     * @notice Accept direct ETH transfers
     */
    receive() external payable {}
}