// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Demo token used ONLY for the course's local-chain experiments.
/// @dev Standard 18-decimal ERC-20; deployer initially receives 1 million tokens.
contract MockToken is ERC20 {
    constructor() ERC20("Demo Shopping Token", "SHOP") {
        _mint(msg.sender, 1_000_000 ether);
    }
}
