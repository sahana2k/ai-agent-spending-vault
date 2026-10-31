# Draft Smart Contract Design and Interfaces

## Design goal

Enforce least-privilege delegated spending for an off-chain shopping agent.
The vault authorizes **token payments**, not arbitrary agent contract calls.

## Contracts

| Contract | Purpose |
|---|---|
| `AgentSpendingVault` | Stores the owner, fixed token address, one current agent grant, merchant allowlists, spending limits, expiry, revocation status, and per-grant request IDs. |
| `MockToken` | Supplies test-only ERC-20 balances for local development and evaluation. |

## Function signatures (baseline)

```solidity
constructor(address tokenAddress);
function fund(uint256 amount) external;
function grantPermissions(
    address agentAddress,
    address[] calldata merchants,
    uint256 budget,
    uint256 perPaymentLimit,
    uint64 expiresAt
) external;
function payMerchant(
    address merchant,
    uint256 amount,
    bytes32 requestId
) external;
function revokePermissions() external;
function withdrawUnused(uint256 amount) external;
function isPermissionActive() external view returns (bool);
function isMerchantApproved(address merchant) external view returns (bool);
function getCurrentGrant() external view returns (Grant memory);
function getVaultBalance() external view returns (uint256);
```

### Responsibility of each major component

- **Funding:** Owner approves the token contract, then deposits tokens into the vault.
- **Grant creation:** Owner sets agent, allowlisted merchants, total budget, per-purchase limit, and deadline.
- **Payment validation:** Verify the caller, active/uncancelled/unexpired grant, approved merchant, nonzero amount, caps, sufficient balance, and unused request ID.
- **State update + transfer:** Reserve request ID and decrement grant budget *before* transferring to merchant; transaction rollback protects against failed transfers.
- **Revocation:** Owner disables the current grant for subsequent on-chain payments.
- **Withdrawal:** Owner may recover unused vault tokens; this may reduce the balance available for future grant payments.
- **Events:** Record deposits, grants, allowed merchants, payments, revocations, and withdrawals for auditing and dashboard history.

## Important design decisions

1. **Single current grant:** Simplifies the first version. A new owner-submitted grant replaces the previous one.
2. **Grant-scoped identifiers:** Allowlist and request replay checks are keyed by `currentGrantId`. Reusing an old request ID in a *new* grant is allowed by design. IDs are unique **within a grant** only.
3. **Token budget vs gas:** The contract caps token amounts, not transaction gas.
4. **No arbitrary calls:** The authorized agent has no general-purpose execution function.
5. **Token scope:** One standard mock ERC-20 token, with 18 decimals, for local evaluation; exotic tokens are out of scope.
6. **Security safeguards:** Solidity checked arithmetic, checks-effects-interactions, `nonReentrant`, and `SafeERC20`.
7. **Recipient honesty:** An approved merchant may still charge unfair prices; the vault does not validate off-chain purchase details.
8. **On-chain transaction ordering:** A payment mined before revocation is not undone; a payment mined after revocation must revert.

## Optional extension: signed delegation (NOT in baseline)

After the core grant/payment flow is tested, a future phase could implement EIP-712 typed owner signatures. The signature must commit to the agent, fixed token, merchant-list hash, budget, per-payment limit, deadline, owner nonce, chain ID and vault address; activation should consume the nonce. EIP-712 itself does not provide replay prevention. This signed grant implementation is **not part of the current draft**.

## Security and testing considerations

- Verify all permissions on-chain. Never trust the Python agent or dashboard to enforce limits.
- Avoid exposing arbitrary ERC-20 spending approvals or arbitrary external calls to the agent.
- Test expired and revoked grants, duplicate requests, allowlist changes between grants, failed transfers, and budget invariants.
- Verify exact expected reverts and events in Foundry.
- Use only test tokens on local Anvil; production deployments require threat modeling, auditing, and expanded testing.
