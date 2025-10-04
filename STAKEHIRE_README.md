# 🎯 StakeHire - Web3 Hiring Platform

StakeHire is a decentralized hiring platform that uses stake-based quality assurance to ensure serious commitment from both companies and applicants. Built on Base Sepolia with Next.js 14 and Foundry.

## 🌟 Features

### For Companies
- **Stake-Based Job Posting**: Companies stake ETH based on follower count and job tier
- **Quality Applications**: Application fees filter out spam and low-quality candidates
- **Refund Mechanism**: 80% stake refund on successful hire within 30 days
- **Reputation System**: Build on-chain reputation through successful hires

### For Applicants
- **Fair Refunds**: Full refund + signing bonus if hired, 50% if reviewed but not selected
- **Reputation NFTs**: Earn Bronze, Silver, Gold, and Platinum badges
- **Transparent Process**: All stakes and refunds managed by smart contracts
- **Application Cooldown**: 1-hour cooldown prevents spam applications

### Smart Contract Features
- **Automated Expiry**: Jobs auto-expire after 30 days with penalty for companies
- **Reentrancy Protection**: OpenZeppelin security standards
- **Gas Optimized**: Efficient contract design for lower transaction costs
- **Pausable**: Emergency pause functionality for security

## 🏗️ Project Structure

```
global-hackathon-v1/
├── stakehire-contracts/     # Foundry smart contracts
│   ├── src/
│   │   ├── StakeHire.sol    # Main contract
│   │   ├── ReputationNFT.sol # NFT badges
│   │   └── Escrow.sol       # Stake management
│   ├── test/                # Comprehensive tests
│   └── script/              # Deployment scripts
│
├── stakehire-frontend/      # Next.js 14 app
│   ├── src/
│   │   ├── app/            # App router pages
│   │   ├── components/     # React components
│   │   ├── config/         # Wagmi config
│   │   └── abi/            # Contract ABIs
│   └── package.json
│
└── picky/
    └── stakehire-flow.md   # Complete flow documentation
```

## 🚀 Quick Start

### Prerequisites
- Node.js 18+
- Foundry (for smart contracts)
- Git

### Smart Contracts Setup

```bash
cd stakehire-contracts

# Install dependencies (if Foundry is installed)
forge install

# Run tests
forge test

# Deploy to Base Sepolia (requires .env setup)
forge script script/Deploy.s.sol:DeployScript --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --verify
```

### Frontend Setup

```bash
cd stakehire-frontend

# Install dependencies
npm install

# Copy environment variables
cp .env.example .env.local

# Add your WalletConnect Project ID to .env.local
# Get one at: https://cloud.walletconnect.com/

# Run development server
npm run dev

# Build for production
npm run build
npm start
```

## 📝 Environment Variables

### Contracts (.env)
```env
PRIVATE_KEY=your_private_key_here
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
ETHERSCAN_API_KEY=your_etherscan_key
```

### Frontend (.env.local)
```env
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=your_project_id
NEXT_PUBLIC_STAKEHIRE_ADDRESS=deployed_contract_address
NEXT_PUBLIC_REPUTATION_NFT_ADDRESS=deployed_nft_address
NEXT_PUBLIC_ESCROW_ADDRESS=deployed_escrow_address
```

## 💰 Economic Model

### Company Staking Formula
```
Base Fee (0.01 ETH) + (Followers/1000) * 0.00001 ETH + Senior Role Bonus (0.005 ETH)
```

### Refund Structure

**For Applicants:**
- Hired: 100% refund + signing bonus
- Reviewed & Rejected: 50% refund
- Auto-Rejected (spam): 0% refund

**For Companies:**
- Successful hire within 30 days: 80% refund
- No hire after 30 days: 50% penalty
- Early cancellation: 100% penalty

## 🔐 Security Features

- **ReentrancyGuard**: Protection against reentrancy attacks
- **Pausable**: Emergency pause mechanism
- **Access Control**: Role-based permissions
- **Time Locks**: Escrow release timing
- **Gas Optimization**: Efficient code patterns

## 🧪 Testing

```bash
cd stakehire-contracts

# Run all tests
forge test

# Run tests with gas reporting
forge test --gas-report

# Run specific test
forge test --match-test test_PostJob

# Fuzz testing
forge test --fuzz-runs 1000
```

## 📊 Contract Functions

### Main Contract (StakeHire.sol)

**Company Functions:**
- `registerCompany(uint256 followerCount)` - Register as a company
- `postJob(...)` - Post a new job with stake
- `reviewApplication(uint256 applicationId, bool isReviewed)` - Review applications
- `hireCandidate(uint256 applicationId, uint256 signingBonus)` - Hire a candidate

**Applicant Functions:**
- `applyForJob(uint256 jobId, string coverLetter, string credentials)` - Apply with stake

**View Functions:**
- `getActiveJobs()` - Get all active job listings
- `getJob(uint256 jobId)` - Get job details
- `getCompanyJobs(address company)` - Get jobs by company
- `getUserApplications(address user)` - Get user's applications

## 🎨 Tech Stack

### Smart Contracts
- **Solidity 0.8.20** - Smart contract language
- **Foundry** - Testing and deployment
- **OpenZeppelin** - Security libraries
- **Base Sepolia** - Deployment network

### Frontend
- **Next.js 14** - React framework
- **TypeScript** - Type safety
- **Wagmi v2** - Ethereum interactions
- **RainbowKit** - Wallet connections
- **TailwindCSS** - Styling
- **React Hook Form** - Form handling
- **React Hot Toast** - Notifications

## 🛣️ Roadmap

### Phase 1 (MVP - Hackathon) ✅
- [x] Core smart contracts
- [x] Foundry tests
- [x] Next.js frontend
- [x] Wallet integration
- [x] Job posting and application flows

### Phase 2 (Post-Hackathon)
- [ ] Deploy to Base Mainnet
- [ ] Integrate real social verification (Twitter/LinkedIn APIs)
- [ ] Add Chainlink price feeds
- [ ] Implement IPFS for job metadata
- [ ] Advanced filtering and search
- [ ] Real-time notifications

### Phase 3 (Future)
- [ ] Multi-chain support
- [ ] DAO governance for platform parameters
- [ ] Token rewards for successful matches
- [ ] AI-powered job matching
- [ ] Interview scheduling integration

## 📖 Documentation

For detailed flow documentation, see [stakehire-flow.md](./picky/stakehire-flow.md)

## 🐛 Known Issues

- Mock data used for job listings (needs contract integration)
- Social follower verification not implemented (manual for MVP)
- IPFS metadata storage pending
- Gas optimization ongoing

## 🤝 Contributing

This is a hackathon project. Contributions welcome after initial submission!

## 📄 License

MIT License - see LICENSE file for details

## 🙏 Acknowledgments

- OpenZeppelin for security contracts
- RainbowKit team for wallet integration
- Base team for the L2 infrastructure
- ACTA for organizing the hackathon

## 📞 Support

For questions or issues:
- Open a GitHub issue
- Join the discussion on Discord

---

**Built with ❤️ for the ACTA Global Hackathon 2025**
