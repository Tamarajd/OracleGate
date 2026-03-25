# OracleGate

This repository contains the **OracleGate** smart contract, a sophisticated implementation of Machine Learning (ML)-powered token gating for the Stacks blockchain. By bridging off-chain predictive analytics with on-chain asset issuance, **OracleGate** enables a dynamic, risk-aware ecosystem for NFT minting and access control.

---

## Table of Contents

1. Project Overview
2. Core Features
3. Technical Architecture
4. Constants and Error Codes
5. Data Schema
6. Private Functions
7. Public Functions
8. Read-Only Functions
9. Administrative Controls
10. Installation and Deployment
11. Security Considerations
12. Contributing
13. License

---

## Project Overview

**OracleGate** is designed to solve the problem of static whitelisting in decentralized applications. Traditional "allow-lists" are often manual and fail to account for changing user behaviors. This contract introduces an asynchronous ML evaluation system where an authorized off-chain oracle analyzes complex datasets—such as wallet history, transaction frequency, and risk profiles—to assign a confidence score to users.

This score acts as a "DeFi Credit Score" or "Trust Score," determining which tier of non-fungible tokens (NFTs) a user is eligible to mint. The integration of a revocation mechanism ensures that the ecosystem remains high-quality by allowing the oracle to burn tokens held by accounts that later exhibit malicious behavior or falling scores.

---

## Core Features

* **Asynchronous ML Evaluation:** Users pay a fee to trigger an off-chain analysis, which is fulfilled by the oracle with a confidence score.
* **Tiered Access Control:** Three distinct NFT tiers (Bronze, Silver, Gold) tied to specific ML score thresholds.
* **Revocation Logic:** The ability for the oracle to remove tokens from users who no longer meet safety or scoring standards.
* **Malicious Actor Shield:** A robust blacklisting system to prevent known bad actors from interacting with the protocol.
* **Flexible Administration:** Comprehensive tools for the owner to adjust fees, pause the contract, and update the oracle principal.

---

## Technical Architecture

The contract is written in **Clarity 2.0**, ensuring post-launch safety through its interpreted, non-Turing complete nature. The architecture follows the Oracle-Request pattern:

1.  **Request:** User calls `request-ml-evaluation` and pays a fee.
2.  **Off-Chain Processing:** The ML Oracle detects the event, runs the model, and determines a score.
3.  **Fulfillment:** The Oracle calls `fulfill-ml-evaluation` to record the score on-chain.
4.  **Action:** The user calls `claim-tiered-token` to mint their asset based on the recorded score.

---

## Constants and Error Codes

The contract uses a standardized set of constants to maintain internal logic and provide clear feedback for failed transactions.

| Constant | Value | Description |
| :--- | :--- | :--- |
| `tier-1-threshold` | u50 | Minimum score required for Bronze tier. |
| `tier-2-threshold` | u75 | Minimum score required for Silver tier. |
| `tier-3-threshold` | u90 | Minimum score required for Gold tier. |
| `err-owner-only` | u100 | Caller is not the contract owner. |
| `err-unauthorized-oracle` | u101 | Caller is not the designated ML oracle. |
| `err-score-too-low` | u102 | User score does not meet the tier requirements. |
| `err-already-minted` | u103 | User has already claimed their one-time token. |
| `err-request-pending` | u104 | An evaluation request is already in progress. |
| `err-no-request` | u105 | No pending request found for the user. |
| `err-not-pending` | u106 | Fulfillment attempted on a non-pending request. |
| `err-paused` | u107 | Contract operations are currently suspended. |
| `err-blacklisted` | u108 | User is barred from contract interaction. |
| `err-invalid-tier` | u109 | The requested tier ID does not exist. |
| `err-not-token-owner` | u110 | The targeted token is not owned by the specified user. |

---

## Data Schema

### Data Variables
* **ml-oracle**: The principal authorized to fulfill score requests.
* **evaluation-fee**: Cost in micro-STX for a new ML analysis.
* **nft-id-nonce**: The auto-incrementing unique identifier for minted NFTs.
* **contract-paused**: A boolean flag to halt all state-changing operations.

### Data Maps
* **user-ml-scores**: `(map principal uint)` — Stores the latest score (0-100).
* **has-minted**: `(map principal bool)` — Tracks minting status.
* **evaluation-requests**: `(map principal { requested-at: uint, is-pending: bool })` — Manages the lifecycle of oracle requests.
* **blacklist**: `(map principal bool)` — Stores the addresses of restricted users.

---

## Private Functions

These functions are internal to the contract and cannot be called by external users.

### `is-oracle`
Checks if a given principal matches the stored `ml-oracle` variable. Used to gate access to fulfillment and revocation logic.

### `assert-not-paused`
A validation helper that throws `err-paused` if the `contract-paused` variable is set to true. It is called at the beginning of most public state-changing functions.

### `assert-not-blacklisted`
Checks the `blacklist` map for the provided user principal. If the user is found, it returns `err-blacklisted`, preventing further execution.

---

## Public Functions

### Administrative Functions
* **`set-oracle`**: Updates the oracle principal. Only the owner can call this.
* **`set-paused`**: Toggles the emergency stop.
* **`set-evaluation-fee`**: Updates the STX cost for requesting an ML analysis.
* **`set-base-token-uri`**: Updates the metadata pointer for the NFT collection.

### Oracle Operations
* **`update-user-score`**: Allows the oracle to push a score update without a prior request (Proactive Scoring).
* **`fulfill-ml-evaluation`**: Resolves a pending user request and records the score.
* **`revoke-token`**: Burns an existing NFT if the user's risk profile changes.
* **`blacklist-user` / `remove-from-blacklist`**: Manages the global restriction list.

### User Operations
* **`request-ml-evaluation`**: Pays the fee and enters the queue for off-chain analysis.
* **`claim-tiered-token`**: The primary minting function. It checks the user's score against the requested tier threshold and issues the NFT if eligible.

---

## Read-Only Functions

These functions provide a way to query the contract state without spending gas or altering the blockchain.

* **`get-user-score`**: Returns the current ML score for a specific principal.
* **`has-user-minted`**: Returns true if the user has already successfully minted a token.
* **`get-user-tier`**: Returns the specific tier (1, 2, or 3) claimed by the user.
* **`get-evaluation-request`**: Returns the metadata associated with a user's current request status.
* **`is-user-blacklisted`**: Returns the blacklist status of a principal.
* **`get-nft-owner`**: Returns the owner of a specific NFT ID.

---

## Security Considerations

1.  **Oracle Trust:** The integrity of the system relies entirely on the `ml-oracle`. If the oracle principal is compromised, an attacker could assign high scores to any wallet.
2.  **Fee Management:** The evaluation fee is paid to a `fee-recipient`. Users should ensure they have sufficient STX before calling the request function.
3.  **Tier Logic:** The contract uses a strict threshold. A score of 89 is insufficient for Tier 3 (Gold), which requires exactly 90 or above.
4.  **Revocation:** Unlike standard NFTs, these tokens are revocable. This is a design choice to ensure that "Gated" status is earned and maintained.

---

## Contributing

I welcome contributions to **OracleGate**. To contribute:

1.  Fork the repository.
2.  Create a feature branch (`git checkout -b feature/AmazingFeature`).
3.  Commit your changes using professional, descriptive messages.
4.  Push to the branch (`git push origin feature/AmazingFeature`).
5.  Open a Pull Request.

---

## License

**MIT License**

Copyright (c) 2026 OracleGate Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

