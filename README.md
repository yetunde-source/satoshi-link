# SatoshiLink Bridge Contract

[![Clarity Version](https://img.shields.io/badge/Clarity-v3-blue.svg)](https://docs.stacks.co/clarity/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Tests](https://img.shields.io/badge/Tests-Vitest-yellow.svg)](https://vitest.dev/)

## Overview

**SatoshiLink** is a sophisticated cross-chain asset bridge that enables secure, validator-governed transfers between Bitcoin and the Stacks blockchain. The protocol ensures compliance, trust minimization, and transparency in all bridging activities through a robust multi-signature validation system.

## Key Features

### 🔐 **Security-First Architecture**

- **Multi-validator confirmation system** requiring 6 validator signatures for deposit confirmation
- **Pause/resume mechanisms** for emergency incident response
- **Emergency controls** for critical event management
- **Comprehensive input validation** for all Bitcoin-related parameters

### 🌉 **Cross-Chain Bridging**

- **Bidirectional transfers** between Bitcoin and Stacks ecosystems
- **Atomic deposit processing** with cryptographic proof verification
- **Transparent withdrawal logging** for off-chain processing
- **Balance tracking** with precise accounting

### ⚡ **Validator Network**

- **Decentralized validator registry** managed by contract deployer
- **Signature-based authorization** for all bridge operations
- **Validator signature tracking** with timestamp verification
- **Anti-replay protection** for deposit confirmations

### 🛡️ **Robust Validation**

- **Bitcoin address validation** (33-byte compressed public keys)
- **Transaction hash verification** (32-byte Bitcoin tx hashes)
- **Signature format validation** (65-byte ECDSA signatures)
- **Amount bounds checking** (100,000 - 1,000,000,000 satoshis)

## Architecture

### Core Components

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Bitcoin       │    │  SatoshiLink    │    │   Stacks        │
│   Network       │◄──►│   Bridge        │◄──►│   Ecosystem     │
│                 │    │   Contract      │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   Validator     │
                    │   Network       │
                    │   (Multi-sig)   │
                    └─────────────────┘
```

### Data Structures

#### Deposits Map

```clarity
(define-map deposits
  { tx-hash: (buff 32) }
  {
    amount: uint,
    recipient: principal,
    processed: bool,
    confirmations: uint,
    timestamp: uint,
    btc-sender: (buff 33),
  }
)
```

#### Validator Registry

```clarity
(define-map validators principal bool)
```

#### Bridge Balances

```clarity
(define-map bridge-balances principal uint)
```

## Smart Contract Interface

### Public Functions

#### Administrative Functions

- `initialize-bridge()` - Initialize the bridge (deployer only)
- `pause-bridge()` - Pause bridge operations (deployer only)
- `resume-bridge()` - Resume bridge operations (deployer only)
- `add-validator(validator: principal)` - Add validator to registry (deployer only)
- `remove-validator(validator: principal)` - Remove validator from registry (deployer only)

#### Bridge Operations

- `initiate-deposit(tx-hash, amount, recipient, btc-sender)` - Initiate Bitcoin deposit (validators only)
- `confirm-deposit(tx-hash, signature)` - Confirm deposit with validator signature (validators only)
- `withdraw(amount, btc-recipient)` - Withdraw to Bitcoin address
- `emergency-withdraw(amount, recipient)` - Emergency withdrawal (deployer only)

### Read-Only Functions

- `get-deposit(tx-hash)` - Retrieve deposit information
- `get-bridge-status()` - Check if bridge is paused
- `get-validator-status(validator)` - Check validator status
- `get-bridge-balance(user)` - Get user's bridge balance
- `is-valid-principal(address)` - Validate Stacks principal
- `is-valid-btc-address(btc-addr)` - Validate Bitcoin address format
- `is-valid-tx-hash(tx-hash)` - Validate Bitcoin transaction hash
- `is-valid-signature(signature)` - Validate signature format
- `validate-deposit-amount(amount)` - Validate deposit amount bounds

## Security Model

### Multi-Signature Validation

The bridge requires **6 validator confirmations** for each deposit, ensuring no single point of failure in the validation process.

### Access Control

- **Contract Deployer**: Full administrative control (pause/resume, validator management, emergency functions)
- **Validators**: Authorized to initiate and confirm deposits
- **Users**: Can withdraw their bridged assets

### Safety Mechanisms

- **Pause Functionality**: Immediate halt of all bridge operations during incidents
- **Amount Limits**: Configurable minimum (100,000 sats) and maximum (1B sats) deposit amounts
- **Replay Protection**: Each deposit can only be processed once
- **Emergency Controls**: Deployer can perform emergency withdrawals if needed

## Installation & Setup

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) v2.0+
- [Node.js](https://nodejs.org/) v18+
- [npm](https://www.npmjs.com/) or [yarn](https://yarnpkg.com/)

### Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/yetunde-source/satoshi-link.git
   cd satoshi-link
   ```

2. **Install dependencies**

   ```bash
   npm install
   ```

3. **Verify installation**

   ```bash
   clarinet check
   ```

## Development

### Running Tests

Execute the full test suite:

```bash
npm test
```

Run tests with coverage and cost analysis:

```bash
npm run test:report
```

Watch mode for continuous testing:

```bash
npm run test:watch
```

### Contract Validation

Check contract syntax and types:

```bash
clarinet check
```

Format contract code:

```bash
clarinet fmt --in-place
```

### Local Development

Start Clarinet console for interactive testing:

```bash
clarinet console
```

Deploy to local devnet:

```bash
clarinet deploy --devnet
```

## Configuration

### Network Settings

The contract supports deployment across multiple networks:

- **Devnet**: `settings/Devnet.toml`
- **Testnet**: `settings/Testnet.toml`
- **Mainnet**: `settings/Mainnet.toml`

### Bridge Parameters

Key configuration constants:

```clarity
(define-constant MIN-DEPOSIT-AMOUNT u100000)      ;; 0.001 BTC
(define-constant MAX-DEPOSIT-AMOUNT u1000000000)  ;; 10 BTC
(define-constant REQUIRED-CONFIRMATIONS u6)       ;; Validator signatures needed
```

## API Reference

### Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 1000 | `ERROR-NOT-AUTHORIZED` | Unauthorized access attempt |
| 1001 | `ERROR-INVALID-AMOUNT` | Amount outside valid range |
| 1002 | `ERROR-INSUFFICIENT-BALANCE` | Insufficient bridge balance |
| 1003 | `ERROR-INVALID-BRIDGE-STATUS` | Invalid bridge state |
| 1004 | `ERROR-INVALID-SIGNATURE` | Invalid cryptographic signature |
| 1005 | `ERROR-ALREADY-PROCESSED` | Transaction already processed |
| 1006 | `ERROR-BRIDGE-PAUSED` | Bridge operations paused |
| 1007 | `ERROR-INVALID-VALIDATOR-ADDRESS` | Invalid validator principal |
| 1008 | `ERROR-INVALID-RECIPIENT-ADDRESS` | Invalid recipient principal |
| 1009 | `ERROR-INVALID-BTC-ADDRESS` | Invalid Bitcoin address format |
| 1010 | `ERROR-INVALID-TX-HASH` | Invalid Bitcoin transaction hash |
| 1011 | `ERROR-INVALID-SIGNATURE-FORMAT` | Invalid signature format |

## Integration Guide

### For Validators

1. **Registration**: Contact contract deployer for validator registration
2. **Deposit Initiation**: Monitor Bitcoin network for deposits and call `initiate-deposit`
3. **Signature Confirmation**: Provide cryptographic proof via `confirm-deposit`

### For Users

1. **Deposit Flow**:
   - Send Bitcoin to bridge address
   - Wait for validator confirmation (6 signatures required)
   - Receive bridged assets in Stacks account

2. **Withdrawal Flow**:
   - Call `withdraw` function with Bitcoin recipient address
   - Monitor off-chain processing for Bitcoin transaction

### For Developers

Example integration:

```typescript
import { Cl } from "@stacks/transactions";

// Check bridge balance
const balance = simnet.callReadOnlyFn(
  "satoshi-link",
  "get-bridge-balance",
  [Cl.standardPrincipal("SP...")],
  deployer
);

// Initiate withdrawal
const withdrawal = simnet.callPublicFn(
  "satoshi-link", 
  "withdraw",
  [Cl.uint(1000000), Cl.bufferFromHex("1234...")],
  user
);
```

## Security Considerations

### Validator Security

- Validators must secure their private keys using hardware security modules (HSMs)
- Multi-factor authentication required for validator operations
- Regular security audits of validator infrastructure

### Smart Contract Security

- Comprehensive input validation on all user inputs
- Protection against reentrancy attacks through careful state management
- Overflow/underflow protection using safe arithmetic operations

### Bridge Security

- Time-locked withdrawals for large amounts (future enhancement)
- Rate limiting for deposit processing (future enhancement)
- Multi-signature treasury management for bridge reserves

## Roadmap

### Phase 1: Core Bridge (Current)

- ✅ Basic deposit/withdrawal functionality
- ✅ Multi-validator confirmation system
- ✅ Emergency pause mechanisms

### Phase 2: Enhanced Security

- 🔄 Time-locked withdrawals for large amounts
- 🔄 Rate limiting and anti-spam measures
- 🔄 Advanced cryptographic proofs

### Phase 3: Ecosystem Integration

- 📋 DeFi protocol integrations
- 📋 Cross-chain yield farming support
- 📋 Lightning Network compatibility

## Contributing

We welcome contributions from the community! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass (`npm test`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- **Documentation**: [Stacks Documentation](https://docs.stacks.co/)
- **Community**: [Stacks Discord](https://discord.gg/stacks)
- **Issues**: [GitHub Issues](https://github.com/yetunde-source/satoshi-link/issues)

## Acknowledgments

- [Stacks Foundation](https://stacks.org/) for blockchain infrastructure
- [Hiro Systems](https://hiro.so/) for development tools
- The Bitcoin and Stacks communities for inspiration and support
