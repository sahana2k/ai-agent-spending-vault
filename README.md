# Blockchain-Enforced Spending Permissions for AI Agents

**Status:** Design-stage prototype for the Blockchain Engineering course. The contract and initial tests are starter code, not audited or approved for real funds.

## 1. Project description

Autonomous shopping agents can select products and initiate payments, but giving an agent unrestricted access to a wallet creates risks such as excessive spending, unauthorized merchants, and compromised agent credentials.

Our project places a **Solidity smart-contract vault** between a user-funded ERC-20 balance and an AI shopping agent. The vault only processes a payment when it satisfies a policy defined by the user:

- Only an authorized agent can request payments.
- Payments go only to approved merchant addresses.
- Every purchase stays within a per-transaction limit.
- Total purchases stay within a grant's cumulative budget.
- Grants expire at a user-defined deadline and can be revoked.
- Each payment request ID can be used only once per grant.
- The user alone can fund the vault, create grants, revoke access, and withdraw tokens.

The demonstration scenario is a grocery-shopping agent with a **100-token budget, a 30-token purchase limit, and three approved merchants**. Product selection and shopping logic remain off-chain. The vault enforces payments on-chain, even if the agent attempts an unauthorized action.

### Why a smart contract?

An application-side instruction to an agent may be ignored or bypassed. The on-chain payment policy is enforced when funds actually move. The system limits *payments*; it does **not** guarantee product quality, fair prices, or honest deliveries.

## 2. Proposed architecture

```text
User / wallet
   |  fund(), grantPermissions(), revokePermissions(), withdrawUnused()
   v
AgentSpendingVault.sol  <--- MockToken.sol (ERC-20 test tokens)
   |  checks: agent, merchant, deadline, per-payment cap,
   |          remaining grant budget, vault balance, request ID
   v
Approved merchant wallet (ERC-20 payment)
   ^
   |  payMerchant(merchant, amount, requestId)
Python deterministic shopping agent  <--- Three sample merchant catalogs

React/TypeScript dashboard: funding, grant configuration, balances,
revocation controls, payment history (planned integration).
```

**Grant model:** The first prototype supports **one active grant at a time**. An owner-submitted new grant replaces the previous active grant. Merchant allowlists and request IDs are scoped to the grant ID, so creating a new grant does not revive an old one.

## 3. Repository contents

```text
.
├── README.md
├── foundry.toml
├── remappings.txt
├── .gitignore
├── contracts/
│   ├── AgentSpendingVault.sol   # Core vault and permission interfaces
│   └── MockToken.sol            # Test-only ERC-20 token
├── test/
│   └── AgentSpendingVault.t.sol # Initial positive and negative test cases
├── docs/
│   ├── CONTRACT_DESIGN.md       # Contracts, functions, security decisions
│   ├── TEST_PLAN.md             # Proposed evaluation and benchmarks
│   └── TEAM_PLAN.md             # Workstream ownership
├── agent/
│   └── README.md                # Future Python simulator
└── dashboard/
    └── README.md                # Future React user interface
```

## 4. Dependencies and setup

### Required for the current contract prototype

- **Foundry** (`forge`, `anvil`) for Solidity compilation, local Ethereum simulation, and testing.
- **Solidity 0.8.12**, matching the course's assigned documentation version.
- **OpenZeppelin Contracts v4.9.6** for `IERC20`, `SafeERC20`, `ReentrancyGuard`, and the mock ERC-20.
- **forge-std** for Solidity unit tests.

### Installation and build

After cloning the public repository and installing Foundry, run these commands in its root:

```bash
git clone https://github.com/YOUR-USERNAME/YOUR-REPO.git
cd YOUR-REPO
forge install OpenZeppelin/openzeppelin-contracts@v4.9.6
forge install foundry-rs/forge-std
forge build
forge test -vv
```

If the repository already tracks Foundry dependencies as Git submodules, use `git submodule update --init --recursive` instead of installing them again.

The starter ZIP excludes downloaded `lib/` dependencies. **Build and tests have not yet been executed in this starter package**, so the team should run `forge build` and `forge test` before describing it as a verified implementation.

### Planned integration dependencies

- Python 3 and `web3.py` for a deterministic agent and receipt verification.
- React, TypeScript, and `ethers.js` for the dashboard.
- A local **Anvil** chain; do not use real assets or mainnet keys.

These integration components are planned but **not implemented in this design-stage submission**.

## 5. How to use / deploy (local prototype)

1. Start the local blockchain: `anvil`.
2. Run `forge build` and `forge test -vv` in a separate terminal.
3. Deploy `MockToken`, then deploy `AgentSpendingVault` with the mock token address. Use Anvil's **test-only** accounts.
4. As the owner, approve the vault to spend mock tokens and call `fund(amount)`.
5. Call `grantPermissions(agent, merchants, budget, perPaymentLimit, expiresAt)`.
6. As the authorized agent, call `payMerchant(merchant, amount, requestId)` for a whitelisted merchant.
7. Read `getCurrentGrant()`, `getVaultBalance()`, and the `PaymentExecuted` events to inspect the policy and transaction history.
8. Try a duplicate request, an unapproved merchant, an overspend, or a revoked/expired grant; each should revert.
9. As the owner, call `revokePermissions()` and/or `withdrawUnused(amount)`.

Amounts are specified in the **token's smallest units**. The mock token has 18 decimals (`100 tokens = 100 ether` in Solidity examples). The vault budget caps token transfers; blockchain gas fees are **separate**.

**Current limitation:** This is an early local-only prototype. There is no production deployment, complete Python agent, or React dashboard yet.

## 6. Planned testing and evaluation

We plan to test authorized purchases, unauthorized callers, non-whitelisted merchants, excessive transaction amounts, cumulative overspending, expired grants, revocation, reused request IDs, and failure atomicity. We will also measure gas for granting, paying, and revoking. See [`docs/TEST_PLAN.md`](docs/TEST_PLAN.md).

**Stretch goals only after the baseline works:** EIP-712 signed grants with nonce-based replay protection, and optional LLM-based purchase selection.

## 7. Team responsibilities

- **Pradnya Sanjeev Nidagundi:** Vault contracts and permissions
- **Mahima Ramdas Bhat:** Deterministic shopping agent and merchant simulation
- **Yash Ravindra Charde:** Dashboard and frontend integration
- **Sahana Jayasimha Holkal:** Adversarial tests, invariants, gas benchmarks, evaluation

Everyone contributes to integration, documentation, and the final demo.

## 8. References

- [Solidity 0.8.12 documentation](https://docs.soliditylang.org/en/v0.8.12/)
- [ERC-20 specification (EIP-20)](https://eips.ethereum.org/EIPS/eip-20)
- [EIP-712 typed structured signing](https://eips.ethereum.org/EIPS/eip-712) (stretch goal)
- [ERC-3009 authorization model](https://eips.ethereum.org/EIPS/eip-3009) (background)
- [Foundry documentation](https://book.getfoundry.sh/)
- [OpenZeppelin Contracts v4](https://docs.openzeppelin.com/contracts/4.x/)

## 9. Responsible use

All experimentation uses local chains and mock tokens only. Do not publish private keys, secrets, or wallet seed phrases. This starter has not undergone independent security review and must not be deployed to manage real funds.
