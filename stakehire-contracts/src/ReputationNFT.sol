// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title ReputationNFT
 * @notice ERC-721 NFTs for reputation badges and credentials
 */
contract ReputationNFT is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    
    // ============ Enums ============
    
    enum BadgeType {
        Bronze,
        Silver,
        Gold,
        Platinum
    }
    
    // ============ Structs ============
    
    struct Badge {
        BadgeType badgeType;
        uint256 score;
        uint256 mintedAt;
        bool isActive;
    }
    
    struct UserReputation {
        uint256 score;
        uint256 totalEndorsements;
        uint256 successfulHires;
        uint256 successfulApplications;
        BadgeType currentBadge;
        bool hasBadge;
    }
    
    // ============ State Variables ============
    
    Counters.Counter private _tokenIdCounter;
    address public stakeHireContract;
    
    // Badge thresholds
    uint256 public constant BRONZE_THRESHOLD = 100;
    uint256 public constant SILVER_THRESHOLD = 500;
    uint256 public constant GOLD_THRESHOLD = 1000;
    uint256 public constant PLATINUM_THRESHOLD = 5000;
    
    // Mappings
    mapping(uint256 => Badge) public badges;
    mapping(address => UserReputation) public userReputations;
    mapping(address => uint256[]) public userBadges;
    mapping(BadgeType => string) public badgeURIs;
    
    // ============ Events ============
    
    event BadgeMinted(address indexed user, uint256 tokenId, BadgeType badgeType, uint256 score);
    event ScoreUpdated(address indexed user, uint256 newScore);
    event BadgeUpgraded(address indexed user, BadgeType oldBadge, BadgeType newBadge);
    event EndorsementReceived(address indexed user, address indexed endorser, uint256 weight);
    
    // ============ Modifiers ============
    
    modifier onlyStakeHire() {
        require(msg.sender == stakeHireContract, "Only StakeHire contract");
        _;
    }
    
    modifier onlyStakeHireOrOwner() {
        require(msg.sender == stakeHireContract || msg.sender == owner(), "Unauthorized");
        _;
    }
    
    // ============ Constructor ============
    
    constructor() ERC721("StakeHire Reputation", "SHREP") {
        // Set default badge URIs (can be updated later to point to IPFS)
        badgeURIs[BadgeType.Bronze] = "ipfs://QmBronzeBadgeURI";
        badgeURIs[BadgeType.Silver] = "ipfs://QmSilverBadgeURI";
        badgeURIs[BadgeType.Gold] = "ipfs://QmGoldBadgeURI";
        badgeURIs[BadgeType.Platinum] = "ipfs://QmPlatinumBadgeURI";
    }
    
    // ============ Main Functions ============
    
    /**
     * @notice Set the StakeHire contract address
     */
    function setStakeHireContract(address _stakeHireContract) external onlyOwner {
        require(_stakeHireContract != address(0), "Invalid address");
        stakeHireContract = _stakeHireContract;
    }
    
    /**
     * @notice Mint a new reputation badge
     */
    function mint(address to, uint256 score) external onlyStakeHireOrOwner {
        require(to != address(0), "Invalid recipient");
        require(score > 0, "Score must be positive");
        
        BadgeType badgeType = getBadgeType(score);
        UserReputation storage userRep = userReputations[to];
        
        // Check if user should receive a badge
        if (!userRep.hasBadge || badgeType > userRep.currentBadge) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            
            _safeMint(to, tokenId);
            _setTokenURI(tokenId, badgeURIs[badgeType]);
            
            badges[tokenId] = Badge({
                badgeType: badgeType,
                score: score,
                mintedAt: block.timestamp,
                isActive: true
            });
            
            userBadges[to].push(tokenId);
            
            BadgeType oldBadge = userRep.currentBadge;
            userRep.hasBadge = true;
            userRep.currentBadge = badgeType;
            userRep.score = score;
            
            emit BadgeMinted(to, tokenId, badgeType, score);
            
            if (oldBadge != badgeType && userRep.hasBadge) {
                emit BadgeUpgraded(to, oldBadge, badgeType);
            }
        }
    }
    
    /**
     * @notice Update user's reputation score
     */
    function updateScore(address user, uint256 newScore) external onlyStakeHire {
        require(user != address(0), "Invalid user");
        
        UserReputation storage userRep = userReputations[user];
        userRep.score = newScore;
        
        // Check if user qualifies for a new badge
        BadgeType newBadgeType = getBadgeType(newScore);
        if (!userRep.hasBadge || newBadgeType > userRep.currentBadge) {
            mint(user, newScore);
        }
        
        emit ScoreUpdated(user, newScore);
    }
    
    /**
     * @notice Add endorsement to a user
     */
    function addEndorsement(address user, address endorser, uint256 weight) external onlyStakeHireOrOwner {
        require(user != address(0) && endorser != address(0), "Invalid addresses");
        require(user != endorser, "Cannot self-endorse");
        require(weight > 0, "Weight must be positive");
        
        UserReputation storage userRep = userReputations[user];
        userRep.totalEndorsements += weight;
        userRep.score += weight * 2; // Each endorsement adds 2 points per weight
        
        emit EndorsementReceived(user, endorser, weight);
        
        // Check for badge upgrade
        BadgeType newBadgeType = getBadgeType(userRep.score);
        if (!userRep.hasBadge || newBadgeType > userRep.currentBadge) {
            mint(user, userRep.score);
        }
    }
    
    /**
     * @notice Record successful hire
     */
    function recordSuccessfulHire(address company) external onlyStakeHire {
        UserReputation storage userRep = userReputations[company];
        userRep.successfulHires++;
        userRep.score += 10;
        
        emit ScoreUpdated(company, userRep.score);
    }
    
    /**
     * @notice Record successful application
     */
    function recordSuccessfulApplication(address applicant) external onlyStakeHire {
        UserReputation storage userRep = userReputations[applicant];
        userRep.successfulApplications++;
        userRep.score += 10;
        
        emit ScoreUpdated(applicant, userRep.score);
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get badge type based on score
     */
    function getBadgeType(uint256 score) public pure returns (BadgeType) {
        if (score >= PLATINUM_THRESHOLD) {
            return BadgeType.Platinum;
        } else if (score >= GOLD_THRESHOLD) {
            return BadgeType.Gold;
        } else if (score >= SILVER_THRESHOLD) {
            return BadgeType.Silver;
        } else if (score >= BRONZE_THRESHOLD) {
            return BadgeType.Bronze;
        } else {
            return BadgeType.Bronze; // Default to Bronze for scores below threshold
        }
    }
    
    /**
     * @notice Get user's current score
     */
    function getScore(address user) external view returns (uint256) {
        return userReputations[user].score;
    }
    
    /**
     * @notice Get user's full reputation data
     */
    function getUserReputation(address user) external view returns (UserReputation memory) {
        return userReputations[user];
    }
    
    /**
     * @notice Get all badges owned by a user
     */
    function getUserBadges(address user) external view returns (uint256[] memory) {
        return userBadges[user];
    }
    
    /**
     * @notice Check if user has a specific badge type
     */
    function hasBadgeType(address user, BadgeType badgeType) external view returns (bool) {
        UserReputation memory userRep = userReputations[user];
        return userRep.hasBadge && userRep.currentBadge >= badgeType;
    }
    
    /**
     * @notice Get badge details
     */
    function getBadgeDetails(uint256 tokenId) external view returns (Badge memory) {
        require(_exists(tokenId), "Token does not exist");
        return badges[tokenId];
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Update badge URI for a specific badge type
     */
    function setBadgeURI(BadgeType badgeType, string memory uri) external onlyOwner {
        badgeURIs[badgeType] = uri;
    }
    
    /**
     * @notice Batch update badge URIs
     */
    function setBadgeURIs(
        string memory bronzeURI,
        string memory silverURI,
        string memory goldURI,
        string memory platinumURI
    ) external onlyOwner {
        badgeURIs[BadgeType.Bronze] = bronzeURI;
        badgeURIs[BadgeType.Silver] = silverURI;
        badgeURIs[BadgeType.Gold] = goldURI;
        badgeURIs[BadgeType.Platinum] = platinumURI;
    }
    
    /**
     * @notice Deactivate a badge (in case of violations)
     */
    function deactivateBadge(uint256 tokenId) external onlyOwner {
        require(_exists(tokenId), "Token does not exist");
        badges[tokenId].isActive = false;
    }
    
    /**
     * @notice Reactivate a badge
     */
    function reactivateBadge(uint256 tokenId) external onlyOwner {
        require(_exists(tokenId), "Token does not exist");
        badges[tokenId].isActive = true;
    }
    
    // ============ Internal Functions ============
    
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
    
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
    
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
    
    // ============ Override Functions ============
    
    /**
     * @notice Override transfer to prevent transfers of deactivated badges
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
        
        if (from != address(0) && to != address(0)) {
            require(badges[tokenId].isActive, "Badge is deactivated");
        }
    }
    
    /**
     * @notice The following functions are overrides required by Solidity.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}