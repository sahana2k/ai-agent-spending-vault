# Adversarial Test Plan and Benchmarks

**Owner:** Sahana Jayasimha Holkal (with team review)

This plan covers the evaluation described in the group proposal. The initial Solidity test file includes several cases, but the full evaluation and gas benchmark report remain future work.

## Positive test cases

- Owner deposits test tokens.
- Owner creates an active policy with permitted merchants.
- Authorized agent pays a permitted merchant within both limits.
- Payment emits a traceable event and reduces remaining grant budget.
- Owner revokes the grant and withdraws unused tokens.
- Owner issues a fresh grant without inheriting a previous grant's merchant allowlist.

## Negative / adversarial test cases

| Scenario | Expected result |
|---|---|
| Stranger calls `grantPermissions` or `withdrawUnused` | Revert; owner-only operation |
| Stranger calls `payMerchant` | Revert; unauthorized agent |
| Agent sends to unapproved merchant | Revert; restricted recipient |
| Agent requests zero or over-limit amount | Revert |
| Total purchases exceed grant budget | Revert |
| Agent pays after deadline | Revert |
| Agent pays after owner revokes grant | Revert |
| Same request ID reused in same grant | Revert |
| Vault has insufficient token balance | Revert with no request ID consumed |
| Owner grants with empty merchant list, zero budget, or invalid expiry | Revert |
| Old merchant from previous grant is used | Revert unless newly approved |

## Property/invariant tests (planned)

- Sum of successful payments under each grant never exceeds its original budget.
- Remaining budget never increases during purchases.
- A failed payment never decreases remaining budget, consumes its ID, or changes merchant balances.
- No payment succeeds after revocation has been processed on-chain.
- No payment succeeds at or after the grant expiration.
- A grant cannot transfer tokens to an unapproved merchant.

## Gas benchmarks (planned)

Record `gasUsed` for:
1. `grantPermissions` with 1 versus 3 merchants.
2. `payMerchant` using a small versus maximum permitted amount.
3. `revokePermissions`.
4. `withdrawUnused`.

Report compiler/version, test environment, number of cases, pass percentage, and min/mean/max gas. **Gas is an Ethereum execution cost, not part of the token spending budget.**

## Not part of baseline

Reused signatures and wrong-chain/wrong-vault signature scenarios are **conditional on implementing the optional EIP-712 extension**. They are not claimed as passing tests in the current prototype.
