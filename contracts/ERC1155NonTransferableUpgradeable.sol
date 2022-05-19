// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./oz/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "./oz/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";

contract ERC1155NonTransferableUpgradeable is
    ERC1155Upgradeable,
    ERC1155SupplyUpgradeable
{
    /// @dev Override of the token transfer hook that blocks all transfers BUT the mint.
    ///        This is a precursor to non-transferable tokens.
    ///        We may adopt something like ERC1238 in the future.
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155Upgradeable, ERC1155SupplyUpgradeable) {
        require(
            (from == address(0) && to != address(0)),
            "Only mint transfers are allowed"
        );
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}