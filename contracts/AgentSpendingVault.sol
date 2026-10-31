// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title AgentSpendingVault
/// @notice Draft local-chain vault that applies owner-defined payment rules
///         before allowing an AI agent to transfer a fixed ERC-20 token.
/// @dev Baseline has ONE current grant. EIP-712 signatures are intentionally
///      outside this stage's scope; grants are submitted by the owner directly.
///      Not audited. Use mock tokens and local Anvil accounts only.
contract AgentSpendingVault is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // The token and vault owner are fixed at deployment.
    IERC20 public immutable token;
    address public immutable owner;

    /// @notice Details of the currently active/most recent grant.
    /// @dev budget and remainingBudget are expressed in token base units.
    struct Grant {
        address agent;
        uint256 budget;
        uint256 remainingBudget;
        uint256 perPaymentLimit;
        uint64 expiresAt;
        bool active;
        bool revoked;
    }

    Grant public grant;
    uint256 public currentGrantId;

    // Per-grant mappings ensure that an older grant's permissions or request
    // identifiers do not automatically carry into a new grant.
    mapping(uint256 => mapping(address => bool)) public approvedMerchant;
    mapping(uint256 => mapping(bytes32 => bool)) public usedRequestId;

    event VaultFunded(address indexed owner, uint256 amount);
    event PermissionsGranted(
        uint256 indexed grantId,
        address indexed agent,
        uint256 budget,
        uint256 perPaymentLimit,
        uint64 expiresAt
    );
    event MerchantApproved(uint256 indexed grantId, address indexed merchant);
    event PaymentExecuted(
        uint256 indexed grantId,
        bytes32 indexed requestId,
        address indexed merchant,
        uint256 amount
    );
    event PermissionsRevoked(uint256 indexed grantId);
    event TokensWithdrawn(address indexed owner, uint256 amount);

    error NotOwner();
    error NotAgent();
    error InvalidAddress();
    error InvalidAmount();
    error InvalidGrant();
    error GrantInactive();
    error GrantExpired();
    error MerchantNotApproved();
    error PaymentLimitExceeded();
    error BudgetExceeded();
    error InsufficientVaultBalance();
    error DuplicateRequest();
    error RequestIdRequired();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @param tokenAddress Fixed ERC-20 token used by every payment.
    constructor(address tokenAddress) {
        if (tokenAddress == address(0)) revert InvalidAddress();
        owner = msg.sender;
        token = IERC20(tokenAddress);
    }

    /// @notice Deposit mock ERC-20 tokens after owner has approved this vault.
    /// @dev SafeERC20 reverts if the token transfer fails.
    function fund(uint256 amount) external onlyOwner nonReentrant {
        if (amount == 0) revert InvalidAmount();
        token.safeTransferFrom(msg.sender, address(this), amount);
        emit VaultFunded(msg.sender, amount);
    }

    /// @notice Set a new agent policy, replacing any previous active policy.
    /// @dev Allowlisted merchants and replay tracking belong to the new grant ID.
    ///      The owner can set a budget larger than the current token balance,
    ///      but a payment also checks the vault balance before transfer.
    /// @param agentAddress Account allowed to request merchant payments.
    /// @param merchants Addresses allowed to receive payments.
    /// @param budget Total maximum amount the agent may spend in this grant.
    /// @param perPaymentLimit Maximum amount for each individual payment.
    /// @param expiresAt Unix timestamp after which payments must revert.
    function grantPermissions(
        address agentAddress,
        address[] calldata merchants,
        uint256 budget,
        uint256 perPaymentLimit,
        uint64 expiresAt
    ) external onlyOwner {
        if (agentAddress == address(0)) revert InvalidAddress();
        if (
            merchants.length == 0 ||
            budget == 0 ||
            perPaymentLimit == 0 ||
            perPaymentLimit > budget ||
            expiresAt <= block.timestamp
        ) revert InvalidGrant();

        // Incrementing the grant ID separates permissions and request IDs.
        currentGrantId += 1;
        grant = Grant({
            agent: agentAddress,
            budget: budget,
            remainingBudget: budget,
            perPaymentLimit: perPaymentLimit,
            expiresAt: expiresAt,
            active: true,
            revoked: false
        });

        for (uint256 i = 0; i < merchants.length; i++) {
            if (merchants[i] == address(0)) revert InvalidAddress();
            approvedMerchant[currentGrantId][merchants[i]] = true;
            emit MerchantApproved(currentGrantId, merchants[i]);
        }

        emit PermissionsGranted(
            currentGrantId,
            agentAddress,
            budget,
            perPaymentLimit,
            expiresAt
        );
    }

    /// @notice Move tokens to a merchant only after checking all grant rules.
    /// @dev Checks-effects-interactions ordering and nonReentrant protection:
    ///      the request ID and remaining budget are updated before token transfer.
    ///      If the token transfer fails, the entire transaction reverts.
    /// @param merchant Approved recipient of the ERC-20 payment.
    /// @param amount Positive token amount not above the payment cap.
    /// @param requestId Unique identifier for this request within the grant.
    function payMerchant(
        address merchant,
        uint256 amount,
        bytes32 requestId
    ) external nonReentrant {
        if (msg.sender != grant.agent) revert NotAgent();
        if (!grant.active || grant.revoked) revert GrantInactive();
        if (block.timestamp >= grant.expiresAt) revert GrantExpired();
        if (!approvedMerchant[currentGrantId][merchant]) revert MerchantNotApproved();
        if (requestId == bytes32(0)) revert RequestIdRequired();
        if (usedRequestId[currentGrantId][requestId]) revert DuplicateRequest();
        if (amount == 0) revert InvalidAmount();
        if (amount > grant.perPaymentLimit) revert PaymentLimitExceeded();
        if (amount > grant.remainingBudget) revert BudgetExceeded();
        if (amount > token.balanceOf(address(this))) revert InsufficientVaultBalance();

        usedRequestId[currentGrantId][requestId] = true;
        grant.remainingBudget -= amount;

        token.safeTransfer(merchant, amount);
        emit PaymentExecuted(currentGrantId, requestId, merchant, amount);
    }

    /// @notice Block future payments using the current grant.
    /// @dev Revocation cannot undo payments already mined on-chain.
    function revokePermissions() external onlyOwner {
        if (!grant.active || grant.revoked) revert GrantInactive();
        grant.revoked = true;
        emit PermissionsRevoked(currentGrantId);
    }

    /// @notice Let the owner withdraw token funds at any time.
    /// @dev A withdrawal may leave less token balance than a grant's remaining
    ///      budget; subsequent payments then fail the balance check.
    function withdrawUnused(uint256 amount) external onlyOwner nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (amount > token.balanceOf(address(this))) revert InsufficientVaultBalance();
        token.safeTransfer(owner, amount);
        emit TokensWithdrawn(owner, amount);
    }

    /// @notice Whether the current grant is currently usable.
    function isPermissionActive() external view returns (bool) {
        return grant.active && !grant.revoked && block.timestamp < grant.expiresAt;
    }

    /// @notice Whether an address is allowed under the current grant.
    function isMerchantApproved(address merchant) external view returns (bool) {
        return approvedMerchant[currentGrantId][merchant];
    }

    /// @notice Current policy for dashboard/agent inspection.
    function getCurrentGrant() external view returns (Grant memory) {
        return grant;
    }

    /// @notice Current mock-token balance in the vault.
    function getVaultBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}
