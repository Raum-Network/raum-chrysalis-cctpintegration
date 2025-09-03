
# 🌉 ChrysalisCCTPIntegration

## 🌐 Overview

This repository is a **Proof of Concept (PoC)** demonstrating a **cross-chain staking architecture** that integrates:

- **Circle CCTP (Cross-Chain Transfer Protocol)** for USDC transfers across chains  
- **Lido Integration** for tokenized staking  
  *(Staking is supported only for Sepolia Network via Lido.)*

The purpose is to build an infrastructure where users can stake USDC on one chain, and have it seamlessly transferred, staked, and represented with a staking token on another chain.

---

## 🔗 Contract Overview

| Contract                  | Description                                                                 |
|---------------------------|-----------------------------------------------------------------------------|
| `CCTPSender.sol`          | Handles initiation of CCTP USDC transfers and cross-chain messages          |
| `CCTPReceiver.sol`        | Receives messages and tokens from CCTP, triggers staking logic              |
| `CCTPHook.sol`            | A middleware that links CCTP message receipt and will be used to call the staking logic via CCTP Message Transmitter |
| `IMessageTransmitter.sol` | Interface to Circle’s cross-chain messaging layer                           |
| `ITokenMinter.sol`        | Interface to Circle’s USDC token minter on destination chain                |
| `ICircleMessenger.sol`    | Circle-specific helper interface for relaying messages                      |
| `IReceiver.sol`           | Interface for contracts accepting payloads (used in CCTPReceiver)           |
| `IRelayer.sol`            | *(Optional)* Interface for custom relayer logic                             |

---

## 🐛 Chrysalis Protocol Integration

The **Chrysalis Protocol** is designed to:

- Accept **CCTP-delivered USDC**
- Stake it into supported DeFi protocols (e.g., **Lido**)
- Mint staking receipt tokens on the source chain, maintaining **1:1 mapping** with staked assets

In this PoC, Chrysalis logic is kept **modular** to allow:

- Easy addition of staking strategies

---

## 🚧 Project Status

This project is currently in **Proof of Concept (PoC)** phase.  
The next milestones include:

- ✅ **CCTP-based cross-chain USDC transfer & staking logic** *(Current)*
- 🔜 **Mainnet-ready architecture** with fallback relayers, gas estimation, and batching *(Phase 2)*
- 🔜 **ERC-4337 Paymaster Integration** for gasless UX on sender chain *(Phase 3)*

---

## 🧱 Tech Stack

- **Solidity** ^0.8.x  
- **Circle CCTP Protocol** and **Circle USDC**  
- **Circle Iris Developers API**  
- **OpenZeppelin libraries**  
- **Future**: Account abstraction (ERC-4337), Circle Paymaster

---

## 🧪 Testing

Currently tested on:

- **Source Chain**: Arbitrum Sepolia  
- **Destination Chain**: Ethereum Sepolia  

Using **CCTP and USDC** along with **staking logic**.

Full unit tests and mainnet fork tests will be introduced in later phases.

### 📄 Sample Transactions

- **Source Chain**:  
  [`0x2a66...de1e3`](https://sepolia.arbiscan.io/tx/0x2a664175fb6008fea0da055a0465e6f3c8dc757dbd7c72bc222fc6b75d0de1e3)

- **Destination Chain**:  
  [`0xc5d5...c868`](https://sepolia.etherscan.io/tx/0xc5d5aef0440a8c4bdb28941a20e350c352913ea2d8544b7e4ddf4c3944d0c868)

> **Note**: Staked asset is transferred via native bridge to the user address.

---

## 🗺️ Architecture Diagram

![cctparchitecure](https://github.com/user-attachments/assets/92d41b95-534c-4b0a-8464-15ddc3d374c6)

---

## 🚀 What's Next?

- Integrate **ERC-4337 Paymaster** to cover user gas fees for sending CCTP messages  
- Add support for **multiple DeFi protocols** via strategy pattern  
- Build a **dashboard and subgraph** for user activity tracking
- Test Cases for **Core Contracts** for easy local testing
