// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "forge-std/Test.sol";
import "../contracts/AgentSpendingVault.sol";
import "../contracts/MockToken.sol";

/// @notice Initial executable-style test cases for the core permission rules.
/// @dev Run with `forge test -vv` after installing dependencies.
contract AgentSpendingVaultTest is Test {
    MockToken internal token;
    AgentSpendingVault internal vault;

    address internal agent = address(0xA11CE);
    address internal merchantA = address(0xB0B);
    address internal merchantB = address(0xC0C);
    address internal stranger = address(0xBAD);

    function setUp() public {
        token = new MockToken();
        vault = new AgentSpendingVault(address(token));

        token.approve(address(vault), 100 ether);
        vault.fund(100 ether);

        address[] memory merchants = new address[](2);
        merchants[0] = merchantA;
        merchants[1] = merchantB;

        vault.grantPermissions(
            agent,
            merchants,
            100 ether,
            30 ether,
            uint64(block.timestamp + 1 days)
        );
    }

    function testValidPaymentUpdatesBalancesAndBudget() public {
        vm.prank(agent);
        vault.payMerchant(merchantA, 25 ether, bytes32("purchase-1"));

        assertEq(token.balanceOf(merchantA), 25 ether);
        AgentSpendingVault.Grant memory g = vault.getCurrentGrant();
        assertEq(g.remainingBudget, 75 ether);
    }

    function testUnauthorizedAgentReverts() public {
        vm.prank(stranger);
        vm.expectRevert(AgentSpendingVault.NotAgent.selector);
        vault.payMerchant(merchantA, 10 ether, bytes32("purchase-2"));
    }

    function testUnapprovedMerchantReverts() public {
        vm.prank(agent);
        vm.expectRevert(AgentSpendingVault.MerchantNotApproved.selector);
        vault.payMerchant(stranger, 10 ether, bytes32("purchase-3"));
    }

    function testPerTransactionLimitReverts() public {
        vm.prank(agent);
        vm.expectRevert(AgentSpendingVault.PaymentLimitExceeded.selector);
        vault.payMerchant(merchantA, 31 ether, bytes32("purchase-4"));
    }

    function testCumulativeBudgetEnforced() public {
        vm.startPrank(agent);
        vault.payMerchant(merchantA, 30 ether, bytes32("purchase-5a"));
        vault.payMerchant(merchantA, 30 ether, bytes32("purchase-5b"));
        vault.payMerchant(merchantA, 30 ether, bytes32("purchase-5c"));

        vm.expectRevert(AgentSpendingVault.BudgetExceeded.selector);
        vault.payMerchant(merchantA, 20 ether, bytes32("purchase-5d"));
        vm.stopPrank();
    }

    function testExpiredGrantReverts() public {
        vm.warp(block.timestamp + 2 days);
        vm.prank(agent);
        vm.expectRevert(AgentSpendingVault.GrantExpired.selector);
        vault.payMerchant(merchantA, 10 ether, bytes32("purchase-6"));
    }

    function testRevokedGrantReverts() public {
        vault.revokePermissions();
        vm.prank(agent);
        vm.expectRevert(AgentSpendingVault.GrantInactive.selector);
        vault.payMerchant(merchantA, 10 ether, bytes32("purchase-7"));
    }

    function testDuplicateRequestIdReverts() public {
        vm.startPrank(agent);
        vault.payMerchant(merchantA, 10 ether, bytes32("purchase-8"));
        vm.expectRevert(AgentSpendingVault.DuplicateRequest.selector);
        vault.payMerchant(merchantA, 10 ether, bytes32("purchase-8"));
        vm.stopPrank();
    }

    function testOnlyOwnerCanGrantOrWithdraw() public {
        address[] memory merchants = new address[](1);
        merchants[0] = merchantA;

        vm.startPrank(stranger);
        vm.expectRevert(AgentSpendingVault.NotOwner.selector);
        vault.grantPermissions(
            stranger, merchants, 10 ether, 5 ether,
            uint64(block.timestamp + 1 days)
        );
        vm.expectRevert(AgentSpendingVault.NotOwner.selector);
        vault.withdrawUnused(10 ether);
        vm.stopPrank();
    }

    function testFailedPaymentDoesNotConsumeRequestId() public {
        // The owner can withdraw funds, but cannot let the agent spend more
        // than the actual token balance, even with remaining grant budget.
        vault.withdrawUnused(90 ether);
        bytes32 requestId = bytes32("purchase-9");

        vm.prank(agent);
        vm.expectRevert(AgentSpendingVault.InsufficientVaultBalance.selector);
        vault.payMerchant(merchantA, 20 ether, requestId);

        assertFalse(vault.usedRequestId(vault.currentGrantId(), requestId));

        // Top up and retry using the SAME request ID.
        token.approve(address(vault), 20 ether);
        vault.fund(20 ether);

        vm.prank(agent);
        vault.payMerchant(merchantA, 20 ether, requestId);
        assertTrue(vault.usedRequestId(vault.currentGrantId(), requestId));
    }

    function testNewGrantDoesNotInheritOldAllowlist() public {
        address[] memory merchants = new address[](1);
        merchants[0] = merchantB;
        vault.grantPermissions(
            agent, merchants, 20 ether, 10 ether,
            uint64(block.timestamp + 1 days)
        );

        vm.prank(agent);
        vm.expectRevert(AgentSpendingVault.MerchantNotApproved.selector);
        vault.payMerchant(merchantA, 5 ether, bytes32("new-grant-1"));
    }
}
