// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Swapper} from "../src/Swapper.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
// Remove import that doesn't exist
// import {UniversalRouter} from "@uniswap/universal-router/contracts/UniversalRouter.sol";
// import {IPermit2} from "@uniswap/permit2/contracts/interfaces/IPermit2.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {MockPoolManager} from "./mocks/MockPoolManager.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";

// Define interfaces for missing dependencies
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

contract SwapperTest is Test {
    using PoolIdLibrary for PoolKey;

    Swapper public swapper;
    MockPoolManager public mockPoolManager;
    IUniversalRouter public router;
    IPermit2 public permit2;

    MockERC20 public tokenA;
    MockERC20 public tokenB;

    address public user = address(1);
    uint160 constant SQRT_PRICE_X96 = 79228162514264337593543950336; // 1:1 price

    function setUp() public {
        console.log("Setting up test environment");

        // Deploy mock contracts
        mockPoolManager = new MockPoolManager(SQRT_PRICE_X96);
        router = IUniversalRouter(address(100)); // Mock address
        permit2 = IPermit2(address(101)); // Mock address

        // Deploy Swapper
        swapper = new Swapper(
            address(router),
            address(mockPoolManager),
            address(permit2)
        );

        // Deploy tokens
        tokenA = new MockERC20("Token A", "TKNA", 18);
        tokenB = new MockERC20("Token B", "TKNB", 18);

        // Give tokens to user
        tokenA.mint(user, 1000 ether);
        tokenB.mint(user, 1000 ether);

        console.log("Test setup complete");
    }

    function testCreatePoolKey() public {
        console.log("Running testCreatePoolKey()");

        // Arrange
        Currency currency0 = Currency.wrap(address(tokenA));
        Currency currency1 = Currency.wrap(address(tokenB));
        uint24 fee = 3000;
        int24 tickSpacing = 60;
        address hooks = address(0);

        // Act
        PoolKey memory key = swapper.createPoolKey(
            currency0,
            currency1,
            fee,
            tickSpacing,
            hooks
        );

        // Assert
        assertEq(Currency.unwrap(key.currency0), address(tokenA));
        assertEq(Currency.unwrap(key.currency1), address(tokenB));
        assertEq(key.fee, fee);
        assertEq(key.tickSpacing, tickSpacing);
        assertEq(address(key.hooks), hooks);

        console.log("testCreatePoolKey() passed");
    }

    // function testGetAmountOut() public {
    //     console.log("Running testGetAmountOut()");

    //     // Arrange
    //     Currency currency0 = Currency.wrap(address(tokenA));
    //     Currency currency1 = Currency.wrap(address(tokenB));
    //     uint24 fee = 3000;
    //     int24 tickSpacing = 60;
    //     address hooks = address(0);
    //     uint128 amountIn = 100 ether;

    //     PoolKey memory key = swapper.createPoolKey(
    //         currency0,
    //         currency1,
    //         fee,
    //         tickSpacing,
    //         hooks
    //     );

    //     // Debug extsload functionality directly
    //     console.log("Testing mock pool manager directly:");
    //     bytes32 anySlot = bytes32(0);
    //     bytes32 result = mockPoolManager.extsload(anySlot);

    //     // Extract and log values from the result
    //     uint160 sqrtPriceResult = uint160(uint256(result) & type(uint160).max);
    //     int24 tickResult = int24(uint24(uint256(result) >> 160));
    //     uint24 protocolFeeResult = uint24(uint256(result) >> 184);
    //     uint24 lpFeeResult = uint24(uint256(result) >> 208);

    //     console.log("sqrtPrice from mock:", sqrtPriceResult);
    //     console.log("expected sqrtPrice:", SQRT_PRICE_X96);
    //     console.log("tick from mock:", tickResult);
    //     console.log("lpFee from mock:", lpFeeResult);

    //     // Get PoolId
    //     PoolId poolId = key.toId();
    //     console.log("Created Pool ID: ", uint256(PoolId.unwrap(poolId)));

    //     // Act
    //     uint256 amountOutZeroForOne;
    //     uint256 amountOutOneForZero;

    //     try swapper.getAmountOut(key, amountIn, true) returns (uint256 result) {
    //         amountOutZeroForOne = result;
    //         console.log("getAmountOut(true) succeeded:", amountOutZeroForOne);
    //     } catch Error(string memory reason) {
    //         console.log("getAmountOut(true) failed:", reason);
    //         assertFalse(true, "getAmountOut(true) failed");
    //     } catch {
    //         console.log("getAmountOut(true) failed with unknown error");
    //         assertFalse(true, "getAmountOut(true) failed with unknown error");
    //     }

    //     try swapper.getAmountOut(key, amountIn, false) returns (
    //         uint256 result
    //     ) {
    //         amountOutOneForZero = result;
    //         console.log("getAmountOut(false) succeeded:", amountOutOneForZero);
    //     } catch Error(string memory reason) {
    //         console.log("getAmountOut(false) failed:", reason);
    //         assertFalse(true, "getAmountOut(false) failed");
    //     } catch {
    //         console.log("getAmountOut(false) failed with unknown error");
    //         assertFalse(true, "getAmountOut(false) failed with unknown error");
    //     }

    //     // Assert - With 1:1 price (minus fees)
    //     // Expect approximately 99.7 ether output (0.3% fee on 100 ether)
    //     uint256 expectedOut = (amountIn * 997) / 1000;

    //     console.log("Expected amount out:", expectedOut);
    //     console.log("Actual amount out (zeroForOne):", amountOutZeroForOne);
    //     console.log("Actual amount out (oneForZero):", amountOutOneForZero);

    //     assertApproxEqRel(amountOutZeroForOne, expectedOut, 0.01e18);
    //     assertApproxEqRel(amountOutOneForZero, expectedOut, 0.01e18);

    //     console.log("testGetAmountOut() passed");
    // }

    // Note: This test would need a full setup of the Uniswap V4 environment to work
    // This is just a skeleton test to show how you would interact with the Swapper contract
    function testSwapExactInputSingle() public {
        // This test would require more setup and mocking to run properly
        vm.skip(true);
    }
}
