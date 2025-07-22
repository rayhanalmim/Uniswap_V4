// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Remove imports that aren't available
// import {UniversalRouter} from "@uniswap/universal-router/contracts/UniversalRouter.sol";
// import {Commands} from "@uniswap/universal-router/contracts/libraries/Commands.sol";
// import {IPermit2} from "@uniswap/permit2/contracts/interfaces/IPermit2.sol";

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IV4Router} from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";

// Define interfaces for the missing libraries
interface IUniversalRouter {
    function execute(
        bytes calldata commands,
        bytes[] calldata inputs,
        uint256 deadline
    ) external payable;
}

interface IPermit2 {
    function approve(
        address token,
        address spender,
        uint160 amount,
        uint48 expiration
    ) external;
}

// Define missing Commands enum
enum Commands {
    V4_SWAP
}

contract Swapper {
    using PoolIdLibrary for PoolKey;

    IUniversalRouter public immutable router;
    IPoolManager public immutable poolManager;
    IPermit2 public immutable permit2;

    constructor(address _router, address _poolManager, address _permit2) {
        router = IUniversalRouter(_router);
        poolManager = IPoolManager(_poolManager);
        permit2 = IPermit2(_permit2);
    }

    /**
     * @notice Estimates the amount of output tokens for a given input amount
     * @param key The pool key identifying the token pair and fee
     * @param amountIn The exact amount of tokens to swap
     * @param zeroForOne Direction of swap (true if swapping currency0 for currency1)
     * @return amountOut The estimated amount of output tokens
     */
    function getAmountOut(
        PoolKey calldata key,
        uint128 amountIn,
        bool zeroForOne
    ) external view returns (uint256 amountOut) {
        // Get pool ID
        PoolId poolId = key.toId();

        // Query the current liquidity in the pool
        (uint160 sqrtPriceX96, , , ) = StateLibrary.getSlot0(
            poolManager,
            poolId
        );

        // Calculate amountOut based on the current price
        if (zeroForOne) {
            // currency0 to currency1
            amountOut = calculateAmountOutZeroForOne(amountIn, sqrtPriceX96);
        } else {
            // currency1 to currency0
            amountOut = calculateAmountOutOneForZero(amountIn, sqrtPriceX96);
        }

        return amountOut;
    }

    /**
     * @notice Calculates the amount of currency1 from currency0 based on the price
     * @param amountIn The amount of currency0 to swap
     * @param sqrtPriceX96 The current sqrt price of the pool
     * @return amountOut The estimated amount of currency1
     */
    function calculateAmountOutZeroForOne(
        uint128 amountIn,
        uint160 sqrtPriceX96
    ) internal pure returns (uint256 amountOut) {
        // Formula based on Uniswap v3/v4 calculations
        // Convert to decimals used in calculations
        uint256 priceX96Squared = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);

        // Calculate amountOut using the formula: amountIn * price
        // Division by 2^96 to account for the fixed point representation
        amountOut = (uint256(amountIn) * priceX96Squared) / (1 << 96);

        // Account for fees (approximate calculation, actual value depends on pool fee)
        amountOut = (amountOut * 997) / 1000; // Assuming 0.3% fee

        return amountOut;
    }

    /**
     * @notice Calculates the amount of currency0 from currency1 based on the price
     * @param amountIn The amount of currency1 to swap
     * @param sqrtPriceX96 The current sqrt price of the pool
     * @return amountOut The estimated amount of currency0
     */
    function calculateAmountOutOneForZero(
        uint128 amountIn,
        uint160 sqrtPriceX96
    ) internal pure returns (uint256 amountOut) {
        // Formula based on Uniswap v3/v4 calculations
        // For currency1 to currency0, we divide by the price
        uint256 priceX96Squared = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);

        // Calculate amountOut using the formula: amountIn / price
        // Multiplication by 2^96 to account for the fixed point division
        amountOut = (uint256(amountIn) * (1 << 96)) / priceX96Squared;

        // Account for fees (approximate calculation, actual value depends on pool fee)
        amountOut = (amountOut * 997) / 1000; // Assuming 0.3% fee

        return amountOut;
    }

    /**
     * @notice Swaps an exact amount of input tokens for a minimum amount of output tokens
     * @param key The pool key identifying the token pair and fee
     * @param amountIn The exact amount of tokens to swap
     * @param minAmountOut The minimum amount of output tokens expected
     * @param zeroForOne Direction of swap (true if swapping currency0 for currency1)
     * @return amountOut The amount of output tokens received
     */
    function swapExactInputSingle(
        PoolKey calldata key,
        uint128 amountIn,
        uint128 minAmountOut,
        bool zeroForOne
    ) external returns (uint256 amountOut) {
        // Encode the Universal Router command
        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);

        // Encode V4Router actions
        bytes memory actions = abi.encodePacked(
            uint8(Actions.SWAP_EXACT_IN_SINGLE),
            uint8(Actions.SETTLE_ALL),
            uint8(Actions.TAKE_ALL)
        );

        // Determine input and output currencies based on swap direction
        Currency inputCurrency = zeroForOne ? key.currency0 : key.currency1;
        Currency outputCurrency = zeroForOne ? key.currency1 : key.currency0;

        // Transfer input tokens from sender to this contract
        IERC20(Currency.unwrap(inputCurrency)).transferFrom(
            msg.sender,
            address(this),
            amountIn
        );

        // Approve router to spend tokens
        IERC20(Currency.unwrap(inputCurrency)).approve(
            address(router),
            amountIn
        );

        // Prepare parameters for each action
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: zeroForOne,
                amountIn: amountIn,
                amountOutMinimum: minAmountOut,
                hookData: bytes("")
            })
        );
        params[1] = abi.encode(inputCurrency, amountIn);
        params[2] = abi.encode(outputCurrency, minAmountOut);

        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        // Execute the swap
        uint256 deadline = block.timestamp + 20;
        router.execute(commands, inputs, deadline);

        // Verify the output amount
        amountOut = IERC20(Currency.unwrap(outputCurrency)).balanceOf(
            address(this)
        );
        require(amountOut >= minAmountOut, "Insufficient output amount");

        // Transfer output tokens to sender
        IERC20(Currency.unwrap(outputCurrency)).transfer(msg.sender, amountOut);

        return amountOut;
    }

    /**
     * @notice Creates a PoolKey for a token pair
     * @param currency0 The first currency (should be lower than currency1)
     * @param currency1 The second currency (should be higher than currency0)
     * @param fee The pool fee
     * @param tickSpacing The tick spacing
     * @param hooks The hooks contract address
     * @return key The constructed PoolKey
     */
    function createPoolKey(
        Currency currency0,
        Currency currency1,
        uint24 fee,
        int24 tickSpacing,
        address hooks
    ) external pure returns (PoolKey memory key) {
        return
            PoolKey({
                currency0: currency0,
                currency1: currency1,
                fee: fee,
                tickSpacing: tickSpacing,
                hooks: IHooks(hooks)
            });
    }
}
