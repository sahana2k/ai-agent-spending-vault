# Planned Python Agent and Merchant Simulator

**Not yet implemented.** The proposal calls for:
- Three simulated grocery merchant catalogs.
- A deterministic product-choice algorithm (no LLM required in baseline).
- Payment requests specifying `merchant`, `amount`, and unique `requestId`.
- Calling `payMerchant` via `web3.py` on a local Anvil network.
- Checking on-chain receipts and transfer events after payments.

The interface to integrate against is documented in `docs/CONTRACT_DESIGN.md`.
