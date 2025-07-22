// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {IExtsload} from "@uniswap/v4-core/src/interfaces/IExtsload.sol";

/**
 * Mock Pool Manager for testing
 * This is a simplified version that only supports the methods needed for testing
 */
contract MockPoolManager is IExtsload {
    uint160 public immutable sqrtPriceX96;
    int24 public tick;
    uint24 public protocolFee;
    uint24 public lpFee;

    constructor(uint160 _sqrtPriceX96) {
        sqrtPriceX96 = _sqrtPriceX96;
        tick = 0;
        protocolFee = 0;
        lpFee = 3000; // 0.3%
    }

    // Implement IExtsload interface
    function extsload(bytes32 slot) external view override returns (bytes32) {
        // Return a prepared slot0 value regardless of input
        bytes32 slot0Value = bytes32(uint256(sqrtPriceX96)) |
            bytes32(uint256(uint24(tick)) << 160) |
            bytes32(uint256(protocolFee) << 184) |
            bytes32(uint256(lpFee) << 208);

        return slot0Value;
    }

    function extsload(
        bytes32 startSlot,
        uint256 nSlots
    ) external view override returns (bytes32[] memory values) {
        values = new bytes32[](nSlots);
        for (uint256 i = 0; i < nSlots; i++) {
            values[i] = this.extsload(bytes32(uint256(startSlot) + i));
        }
        return values;
    }

    function extsload(
        bytes32[] calldata slots
    ) external view override returns (bytes32[] memory values) {
        values = new bytes32[](slots.length);
        for (uint256 i = 0; i < slots.length; i++) {
            values[i] = this.extsload(slots[i]);
        }
        return values;
    }
}
