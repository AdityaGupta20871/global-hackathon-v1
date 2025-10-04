// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IReputationNFT {
    function mint(address to, uint256 score) external;
    function updateScore(address user, uint256 score) external;
    function getScore(address user) external view returns (uint256);
}

/**
 * @title StakeHire
 * @notice Web3 hiring platform with stake-based quality assurance
 */
contract StakeHire is ReentrancyGuard, Pausable, Ownable {
    // ============ Structs ============
    
    struct Job {
        uint256 id;
        address company;
        string title;
        string description;
        string requirements;
        uint256 salary;
        uint256 applicationFee;
        uint256 companyStake;
        uint256 maxApplicants;
        uint256 currentApplicants;
        uint256 createdAt;
        uint256 expiresAt;
        bool isActive;
        bool isFilled;
        address hiredCandidate;
    }

    struct Application {
        uint256 jobId;
        address applicant;
        string coverLetter;
        string credentials;
        uint256 stakeAmount;
        uint256 appliedAt;
        ApplicationStatus status;
    }

    struct Company {
        uint256 followerCount;
        uint256 reputationScore;
        uint256 totalJobsPosted;
        uint256 successfulHires;
        uint256 failedJobs;
        bool isVerified;
    }

    struct Applicant {
        uint256 reputationScore;
        uint256 totalApplications;
        uint256 successfulApplications;
        uint256[] endorsements;
        bool isVerified;
    }

    enum ApplicationStatus {
        Pending,
        Reviewed,
        Rejected,
        Hired,
        AutoRejected,
        Refunded
    }

    // ============ State Variables ============
    
    IReputationNFT public reputationNFT;
    
    uint256 public nextJobId = 1;
    uint256 public nextApplicationId = 1;
    
    // Constants
    uint256 public constant BASE_COMPANY_STAKE = 0.01 ether;
    uint256 public constant FOLLOWER_MULTIPLIER = 0.00001 ether;
    uint256 public constant SENIOR_ROLE_BONUS = 0.005 ether;
    uint256 public constant MIN_APPLICATION_FEE = 0.005 ether;
    uint256 public constant JOB_DURATION = 30 days;
    uint256 public constant REVIEW_DEADLINE = 7 days;
    uint256 public constant APPLICATION_COOLDOWN = 1 hours;
    
    // Fee percentages (basis points)
    uint256 public constant HIRED_COMPANY_REFUND_BPS = 8000; // 80%
    uint256 public constant REVIEWED_APPLICANT_REFUND_BPS = 5000; // 50%
    uint256 public constant EXPIRED_COMPANY_PENALTY_BPS = 5000; // 50%
    uint256 public constant PLATFORM_FEE_BPS = 250; // 2.5%
    
    // Mappings
    mapping(uint256 => Job) public jobs;
    mapping(uint256 => Application) public applications;
    mapping(address => Company) public companies;
    mapping(address => Applicant) public applicants;
    mapping(address => uint256) public platformEarnings;
    
    // Job-Application relationships
    mapping(uint256 => uint256[]) public jobApplications;
    mapping(address => uint256[]) public userApplications;
    mapping(address => uint256[]) public companyJobs;
    mapping(uint256 => mapping(address => bool)) public hasApplied;
    mapping(address => uint256) public lastApplicationTime;
    
    // ============ Events ============
    
    event JobPosted(uint256 indexed jobId, address indexed company, uint256 stake, uint256 applicationFee);
    event ApplicationSubmitted(uint256 indexed applicationId, uint256 indexed jobId, address indexed applicant, uint256 stake);
    event ApplicationReviewed(uint256 indexed applicationId, ApplicationStatus status);
    event CandidateHired(uint256 indexed jobId, address indexed applicant, uint256 signingBonus);
    event JobExpired(uint256 indexed jobId, uint256 refundedAmount);
    event StakeRefunded(address indexed user, uint256 amount);
    event ReputationUpdated(address indexed user, uint256 newScore);
    
    // ============ Modifiers ============
    
    modifier onlyCompany(uint256 jobId) {
        require(jobs[jobId].company == msg.sender, "Not job owner");
        _;
    }
    
    modifier jobExists(uint256 jobId) {
        require(jobs[jobId].id != 0, "Job does not exist");
        _;
    }
    
    modifier applicationExists(uint256 applicationId) {
        require(applications[applicationId].jobId != 0, "Application does not exist");
        _;
    }
    
    modifier notExpired(uint256 jobId) {
        require(block.timestamp <= jobs[jobId].expiresAt, "Job expired");
        _;
    }
    
    // ============ Constructor ============
    
    constructor(address _reputationNFT) {
        reputationNFT = IReputationNFT(_reputationNFT);
    }
    
    // ============ Company Functions ============
    
    /**
     * @notice Register as a company with follower verification
     * @param followerCount Verified follower count from oracle/social platform
     */
    function registerCompany(uint256 followerCount) external {
        Company storage company = companies[msg.sender];
        require(!company.isVerified, "Already registered");
        
        company.followerCount = followerCount;
        company.isVerified = true;
        company.reputationScore = 100; // Starting reputation
    }
    
    /**
     * @notice Post a new job with required stake
     */
    function postJob(
        string calldata title,
        string calldata description,
        string calldata requirements,
        uint256 salary,
        uint256 applicationFee,
        uint256 maxApplicants,
        bool isSeniorRole
    ) external payable whenNotPaused nonReentrant {
        require(companies[msg.sender].isVerified, "Company not verified");
        require(applicationFee >= MIN_APPLICATION_FEE, "Fee too low");
        require(maxApplicants > 0 && maxApplicants <= 100, "Invalid max applicants");
        
        // Calculate required stake
        uint256 requiredStake = calculateCompanyStake(msg.sender, isSeniorRole);
        require(msg.value >= requiredStake, "Insufficient stake");
        
        uint256 jobId = nextJobId++;
        
        jobs[jobId] = Job({
            id: jobId,
            company: msg.sender,
            title: title,
            description: description,
            requirements: requirements,
            salary: salary,
            applicationFee: applicationFee,
            companyStake: msg.value,
            maxApplicants: maxApplicants,
            currentApplicants: 0,
            createdAt: block.timestamp,
            expiresAt: block.timestamp + JOB_DURATION,
            isActive: true,
            isFilled: false,
            hiredCandidate: address(0)
        });
        
        companyJobs[msg.sender].push(jobId);
        companies[msg.sender].totalJobsPosted++;
        
        emit JobPosted(jobId, msg.sender, msg.value, applicationFee);
    }
    
    /**
     * @notice Review an application and update its status
     */
    function reviewApplication(
        uint256 applicationId,
        bool isReviewed
    ) external applicationExists(applicationId) nonReentrant {
        Application storage application = applications[applicationId];
        Job storage job = jobs[application.jobId];
        
        require(job.company == msg.sender, "Not job owner");
        require(application.status == ApplicationStatus.Pending, "Already reviewed");
        require(job.isActive && !job.isFilled, "Job not active");
        
        if (isReviewed) {
            application.status = ApplicationStatus.Reviewed;
            // Refund 50% to applicant
            uint256 refundAmount = (application.stakeAmount * REVIEWED_APPLICANT_REFUND_BPS) / 10000;
            payable(application.applicant).transfer(refundAmount);
            
            // Company keeps 50%
            platformEarnings[job.company] += application.stakeAmount - refundAmount;
        } else {
            application.status = ApplicationStatus.AutoRejected;
            // Company keeps 100%
            platformEarnings[job.company] += application.stakeAmount;
        }
        
        emit ApplicationReviewed(applicationId, application.status);
    }
    
    /**
     * @notice Hire a candidate and process settlements
     */
    function hireCandidate(
        uint256 applicationId,
        uint256 signingBonus
    ) external payable applicationExists(applicationId) nonReentrant {
        Application storage application = applications[applicationId];
        Job storage job = jobs[application.jobId];
        
        require(job.company == msg.sender, "Not job owner");
        require(!job.isFilled, "Position already filled");
        require(job.isActive, "Job not active");
        require(application.status == ApplicationStatus.Reviewed, "Applicant not reviewed");
        require(msg.value >= signingBonus, "Insufficient signing bonus");
        
        // Mark as hired
        application.status = ApplicationStatus.Hired;
        job.isFilled = true;
        job.isActive = false;
        job.hiredCandidate = application.applicant;
        
        // Process refunds and bonuses
        uint256 totalToApplicant = application.stakeAmount + signingBonus;
        payable(application.applicant).transfer(totalToApplicant);
        
        // Refund 80% of company stake
        uint256 companyRefund = (job.companyStake * HIRED_COMPANY_REFUND_BPS) / 10000;
        uint256 platformFee = job.companyStake - companyRefund;
        
        payable(job.company).transfer(companyRefund);
        platformEarnings[owner()] += platformFee;
        
        // Update reputation scores
        updateReputationScores(job.company, application.applicant, true);
        
        // Process refunds for other applicants
        refundOtherApplicants(application.jobId, applicationId);
        
        emit CandidateHired(application.jobId, application.applicant, signingBonus);
    }
    
    // ============ Applicant Functions ============
    
    /**
     * @notice Apply for a job with stake
     */
    function applyForJob(
        uint256 jobId,
        string calldata coverLetter,
        string calldata credentials
    ) external payable jobExists(jobId) notExpired(jobId) whenNotPaused nonReentrant {
        Job storage job = jobs[jobId];
        
        require(job.isActive && !job.isFilled, "Job not available");
        require(!hasApplied[jobId][msg.sender], "Already applied");
        require(job.currentApplicants < job.maxApplicants, "Max applicants reached");
        require(msg.value >= job.applicationFee, "Insufficient stake");
        
        // Check cooldown
        require(
            block.timestamp >= lastApplicationTime[msg.sender] + APPLICATION_COOLDOWN,
            "Application cooldown active"
        );
        
        uint256 applicationId = nextApplicationId++;
        
        applications[applicationId] = Application({
            jobId: jobId,
            applicant: msg.sender,
            coverLetter: coverLetter,
            credentials: credentials,
            stakeAmount: msg.value,
            appliedAt: block.timestamp,
            status: ApplicationStatus.Pending
        });
        
        jobApplications[jobId].push(applicationId);
        userApplications[msg.sender].push(applicationId);
        hasApplied[jobId][msg.sender] = true;
        lastApplicationTime[msg.sender] = block.timestamp;
        job.currentApplicants++;
        
        if (!applicants[msg.sender].isVerified) {
            applicants[msg.sender].isVerified = true;
            applicants[msg.sender].reputationScore = 100;
        }
        applicants[msg.sender].totalApplications++;
        
        emit ApplicationSubmitted(applicationId, jobId, msg.sender, msg.value);
    }
    
    // ============ Automated Functions ============
    
    /**
     * @notice Process expired jobs and handle refunds
     */
    function processExpiredJob(uint256 jobId) external jobExists(jobId) nonReentrant {
        Job storage job = jobs[jobId];
        
        require(block.timestamp > job.expiresAt, "Job not expired");
        require(job.isActive, "Job already processed");
        require(!job.isFilled, "Job was filled");
        
        job.isActive = false;
        
        // Penalize company - keep 50% of stake
        uint256 penalty = (job.companyStake * EXPIRED_COMPANY_PENALTY_BPS) / 10000;
        uint256 companyRefund = job.companyStake - penalty;
        
        if (companyRefund > 0) {
            payable(job.company).transfer(companyRefund);
        }
        platformEarnings[owner()] += penalty;
        
        // Update company reputation
        companies[job.company].failedJobs++;
        updateReputationScores(job.company, address(0), false);
        
        // Refund all pending applicants
        refundAllApplicants(jobId);
        
        emit JobExpired(jobId, companyRefund);
    }
    
    // ============ Helper Functions ============
    
    function calculateCompanyStake(address company, bool isSeniorRole) public view returns (uint256) {
        uint256 stake = BASE_COMPANY_STAKE;
        stake += (companies[company].followerCount * FOLLOWER_MULTIPLIER) / 1000;
        if (isSeniorRole) {
            stake += SENIOR_ROLE_BONUS;
        }
        return stake;
    }
    
    function updateReputationScores(address company, address applicant, bool isSuccessful) internal {
        if (isSuccessful) {
            companies[company].successfulHires++;
            companies[company].reputationScore += 10;
            
            if (applicant != address(0)) {
                applicants[applicant].successfulApplications++;
                applicants[applicant].reputationScore += 10;
                reputationNFT.updateScore(applicant, applicants[applicant].reputationScore);
            }
        } else {
            if (companies[company].reputationScore >= 5) {
                companies[company].reputationScore -= 5;
            }
        }
        
        emit ReputationUpdated(company, companies[company].reputationScore);
    }
    
    function refundOtherApplicants(uint256 jobId, uint256 hiredApplicationId) internal {
        uint256[] memory applicationIds = jobApplications[jobId];
        
        for (uint256 i = 0; i < applicationIds.length; i++) {
            if (applicationIds[i] != hiredApplicationId) {
                Application storage app = applications[applicationIds[i]];
                if (app.status == ApplicationStatus.Pending || app.status == ApplicationStatus.Reviewed) {
                    app.status = ApplicationStatus.Refunded;
                    uint256 refundAmount = app.stakeAmount;
                    if (refundAmount > 0) {
                        payable(app.applicant).transfer(refundAmount);
                        emit StakeRefunded(app.applicant, refundAmount);
                    }
                }
            }
        }
    }
    
    function refundAllApplicants(uint256 jobId) internal {
        uint256[] memory applicationIds = jobApplications[jobId];
        
        for (uint256 i = 0; i < applicationIds.length; i++) {
            Application storage app = applications[applicationIds[i]];
            if (app.status == ApplicationStatus.Pending) {
                app.status = ApplicationStatus.Refunded;
                uint256 refundAmount = app.stakeAmount;
                if (refundAmount > 0) {
                    payable(app.applicant).transfer(refundAmount);
                    emit StakeRefunded(app.applicant, refundAmount);
                }
            }
        }
    }
    
    // ============ View Functions ============
    
    function getJob(uint256 jobId) external view returns (Job memory) {
        return jobs[jobId];
    }
    
    function getApplication(uint256 applicationId) external view returns (Application memory) {
        return applications[applicationId];
    }
    
    function getJobApplications(uint256 jobId) external view returns (uint256[] memory) {
        return jobApplications[jobId];
    }
    
    function getUserApplications(address user) external view returns (uint256[] memory) {
        return userApplications[user];
    }
    
    function getCompanyJobs(address company) external view returns (uint256[] memory) {
        return companyJobs[company];
    }
    
    function getActiveJobs() external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 1; i < nextJobId; i++) {
            if (jobs[i].isActive && !jobs[i].isFilled) {
                count++;
            }
        }
        
        uint256[] memory activeJobs = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 1; i < nextJobId; i++) {
            if (jobs[i].isActive && !jobs[i].isFilled) {
                activeJobs[index++] = i;
            }
        }
        
        return activeJobs;
    }
    
    // ============ Admin Functions ============
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    function withdrawPlatformEarnings() external onlyOwner nonReentrant {
        uint256 amount = platformEarnings[owner()];
        require(amount > 0, "No earnings to withdraw");
        platformEarnings[owner()] = 0;
        payable(owner()).transfer(amount);
    }
    
    function setReputationNFT(address _reputationNFT) external onlyOwner {
        reputationNFT = IReputationNFT(_reputationNFT);
    }
    
    receive() external payable {}
}