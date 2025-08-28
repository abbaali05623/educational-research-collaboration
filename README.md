# Educational Research Collaboration Contract

A decentralized smart contract platform for coordinating educational research projects and funding on the Stacks blockchain using Clarity.

## Overview

This contract enables researchers, institutions, and funders to collaborate on educational research projects through a transparent, milestone-based funding system. It facilitates project registration, collaboration management, funding coordination, and milestone-based fund disbursement.

## Features

### Core Functionality
- **Project Registration**: Researchers can register new educational research projects with detailed specifications
- **Collaboration Management**: Add and manage project collaborators with appropriate permissions
- **Milestone-Based Funding**: Define project milestones with associated funding amounts
- **Transparent Fund Management**: Track funding contributions and automatic disbursements
- **Project Status Tracking**: Monitor project progress through various lifecycle states
- **Secure Fund Disbursement**: Release funds only when milestones are completed and verified

### Key Benefits
- **Transparency**: All transactions and project updates recorded on-chain
- **Accountability**: Milestone-based funding ensures progress verification
- **Decentralized**: No central authority controls fund management
- **Educational Focus**: Specifically designed for academic and research contexts
- **Cost Effective**: Reduced administrative overhead through automation

## Technical Stack

- **Blockchain**: Stacks Network
- **Smart Contract Language**: Clarity
- **Development Framework**: Clarinet
- **Testing Framework**: Vitest
- **Package Management**: npm

## Project Structure

```
educational-research-collaboration/
├── contracts/
│   └── research-collaboration.clar    # Main contract implementation
├── tests/
│   └── research-collaboration.test.ts # Contract test suite
├── settings/
│   ├── Devnet.toml                   # Development network settings
│   ├── Testnet.toml                  # Testnet configuration
│   └── Mainnet.toml                  # Mainnet configuration
├── Clarinet.toml                     # Project configuration
├── package.json                      # Node.js dependencies
└── README.md                         # This file
```

## Data Models

### Project Structure
- **ID**: Unique project identifier
- **Title**: Project name and description
- **Owner**: Principal address of project creator
- **Budget**: Total project funding requirement
- **Status**: Current project state (active, completed, cancelled)
- **Milestone Count**: Number of project milestones
- **Creation Date**: Block height when project was registered

### Milestone Structure
- **Project ID**: Associated project reference
- **Index**: Milestone sequence number
- **Description**: Milestone deliverable details
- **Amount**: Funding allocated for this milestone
- **Completion Status**: Whether milestone has been achieved

### Contribution Tracking
- **Project ID**: Target project reference
- **Contributor**: Funder's principal address
- **Amount**: STX contribution amount

## Quick Start

### Prerequisites
- [Clarinet](https://docs.hiro.so/clarinet) installed
- [Node.js](https://nodejs.org/) (v16 or higher)
- [Stacks Wallet](https://www.hiro.so/wallet) for testing

### Installation
```bash
# Clone the repository
git clone <repository-url>
cd educational-research-collaboration

# Install dependencies
npm install

# Check contract syntax
clarinet check

# Run tests
npm test
```

### Development Commands
```bash
# Syntax and semantic validation
clarinet check

# Run contract tests
clarinet test

# Test coverage analysis
clarinet coverage

# Start local development environment
clarinet integrate
```

## Contract Interface

### Public Functions
- `register-project(title, budget, milestone-count)` - Register new research project
- `add-collaborator(project-id, collaborator)` - Add project team member
- `fund-project(project-id)` - Contribute STX funding to project
- `mark-milestone-complete(project-id, index)` - Mark milestone as achieved
- `disburse-funds(project-id, index)` - Release milestone funding
- `update-project-status(project-id, new-status)` - Change project state

### Read-Only Functions
- `get-project(project-id)` - Retrieve project details
- `get-milestone(project-id, index)` - Get milestone information
- `get-project-funding(project-id)` - Check funding status
- `list-user-projects(owner)` - Get projects by owner
- `get-collaborators(project-id)` - List project team members

## Usage Examples

### Register a Research Project
```clarity
(contract-call? .research-collaboration register-project 
  "AI Ethics in Education" 
  u1000000 ; 10 STX budget
  u3)      ; 3 milestones
```

### Fund a Project
```clarity
(contract-call? .research-collaboration fund-project u1)
```

### Mark Milestone Complete
```clarity
(contract-call? .research-collaboration mark-milestone-complete u1 u0)
```

## Security Considerations

- **Access Control**: Only project owners and collaborators can modify projects
- **Fund Safety**: STX tokens held in contract until milestone completion
- **Input Validation**: All parameters validated before processing
- **No External Dependencies**: Self-contained contract with no cross-contract calls
- **Audit Ready**: Clean, readable code structure for security review

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-feature`)
3. Commit your changes (`git commit -am 'Add new feature'`)
4. Push to the branch (`git push origin feature/new-feature`)
5. Create a Pull Request

## Testing

The contract includes comprehensive tests covering:
- Project registration and validation
- Funding mechanisms and edge cases
- Milestone completion and verification
- Access control and permissions
- Error handling and edge cases

## License

MIT License - see LICENSE file for details.

## Support

For questions or issues:
- Create an issue in this repository
- Review the Clarinet documentation
- Join the Stacks community Discord

---

**Developed by**: alex-research-dev  
**Version**: 1.0.0  
**Last Updated**: August 2025
