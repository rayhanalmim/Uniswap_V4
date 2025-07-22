# Uniswap V4 Swapper

This project implements a token swapping contract for Uniswap V4, allowing users to swap exact amounts of tokens with real-time price estimation.

## Overview

The project contains:

- `Swapper.sol`: Main contract for swapping tokens using Uniswap V4
- `Counter.sol`: Example hook implementation from the Uniswap V4 docs
- Tests for the Swapper contract

## Important Note on Dependencies

This project creates interfaces for dependencies that may not be available in the default Uniswap V4 template:

- UniversalRouter
- Permit2

Instead of using the external packages, we've created simple interfaces for these components to allow the code to compile. In a production environment, you would need to add these dependencies:

```bash
forge install uniswap/universal-router --no-commit
forge install uniswap/permit2 --no-commit
```

## Contract Explanation

### Swapper.sol

The `Swapper` contract serves as an interface for interacting with Uniswap V4 pools through the Universal Router. Here's how it works:

1. **Contract Architecture**:
   - Uses UniversalRouter to execute swaps
   - Interacts with PoolManager to get price data
   - Manages token approvals and transfers

2. **Key Concepts**:

   - **PoolKey**: A struct that uniquely identifies a Uniswap V4 pool. It contains:
     - `currency0`: The token with the lower address
     - `currency1`: The token with the higher address
     - `fee`: The pool's fee tier (e.g., 3000 for 0.3%)
     - `tickSpacing`: The spacing between ticks for this pool
     - `hooks`: The address of any hooks used by this pool

   - **zeroForOne**: A boolean that determines the swap direction:
     - `true`: Swapping currency0 for currency1
     - `false`: Swapping currency1 for currency0

   - **Currency Ordering**: Tokens in a pool are ordered by their addresses (lower address is currency0).
     This ordering is important for determining swap direction.

3. **Main Functions**:

   - **swapExactInputSingle**: Executes a token swap with exact input amount
     ```solidity
     function swapExactInputSingle(
         PoolKey calldata key,
         uint128 amountIn,
         uint128 minAmountOut,
         bool zeroForOne
     ) external returns (uint256 amountOut)
     ```

   - **getAmountOut**: Estimates output amount for a given input
     ```solidity
     function getAmountOut(
         PoolKey calldata key,
         uint128 amountIn,
         bool zeroForOne
     ) external view returns (uint256 amountOut)
     ```

   - **createPoolKey**: Helper function to create a PoolKey struct
     ```solidity
     function createPoolKey(
         Currency currency0,
         Currency currency1,
         uint24 fee,
         int24 tickSpacing,
         address hooks
     ) external pure returns (PoolKey memory key)
     ```

4. **Swap Execution Flow**:
   - Determine input and output currencies based on zeroForOne
   - Transfer input tokens from user to contract
   - Approve the router to spend the tokens
   - Encode the Universal Router command (V4_SWAP)
   - Encode actions (SWAP_EXACT_IN_SINGLE, SETTLE_ALL, TAKE_ALL)
   - Prepare parameters for each action
   - Execute the swap through the router
   - Transfer output tokens back to the user

5. **Price Estimation**:
   - Uses the pool's current sqrtPriceX96 to estimate the output amount
   - Applies fee calculation to give a realistic estimate
   - Different formulas for zeroForOne vs oneForZero swaps

## Deployment and Integration Guide

### Prerequisites

1. Install Foundry:
```
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. Clone and set up the repository:
```
git clone <your-repository-url>
cd v1/v4-template
forge install
```

### Deployment Steps

1. **Update Solidity Version**:
   The project uses Solidity ^0.8.19 to ensure compatibility with the Uniswap V4 contracts.

2. **Compile the contracts**:
```
forge build
```

3. **Deploy to testnet** (example using Sepolia):
```
forge script script/DeploySwapper.s.sol --rpc-url https://sepolia.infura.io/v3/YOUR_INFURA_KEY --private-key YOUR_PRIVATE_KEY --broadcast
```

4. **Verify contract on Etherscan**:
```
forge verify-contract --chain-id 11155111 --compiler-version 0.8.19 DEPLOYED_CONTRACT_ADDRESS src/Swapper.sol:Swapper --etherscan-api-key YOUR_ETHERSCAN_API_KEY
```

### Integration with Frontend Applications

1. **Install the required npm packages**:
```
npm install ethers
```

2. **Set up the contract ABIs**:
   - Create an `abi` directory in your frontend project
   - Add `Swapper.json` and `ERC20.json` files with the respective ABIs

3. **Import the SwapForm component**:
```jsx
import SwapForm from './SwapForm';
```

4. **Use the component in your React app**:
```jsx
<SwapForm 
  provider={yourWeb3Provider} 
  swapperAddress="YOUR_DEPLOYED_CONTRACT_ADDRESS" 
/>
```

5. **Connect to the deployed contract**:
```jsx
const swapper = new ethers.Contract(swapperAddress, SwapperABI, provider);
```

### Key Integration Points

1. **Creating a Pool Key**:
```jsx
const createPoolKey = (tokenA, tokenB) => {
  // Ensure tokens are in the correct order (lower address first)
  const [currency0, currency1] = tokenA.address.toLowerCase() < tokenB.address.toLowerCase() 
    ? [tokenA, tokenB] 
    : [tokenB, tokenA];

  return {
    currency0: currency0.address,
    currency1: currency1.address,
    fee: 3000, // 0.3% fee tier
    tickSpacing: 60,
    hooks: ethers.ZeroAddress
  };
};
```

2. **Determining Swap Direction (zeroForOne)**:
```jsx
const isZeroForOne = (tokenA, tokenB) => {
  return tokenA.address.toLowerCase() < tokenB.address.toLowerCase();
};
```

3. **Getting Estimated Output**:
```jsx
const estimatedOutput = await swapper.getAmountOut(
  poolKey,
  amountIn,
  zeroForOne
);
```

4. **Executing a Swap**:
```jsx
// Approve tokens first
const approveTx = await inputToken.approve(swapperAddress, amountIn);
await approveTx.wait();

// Execute the swap
const swapTx = await swapper.swapExactInputSingle(
  poolKey,
  amountIn,
  minAmountOut,
  zeroForOne
);
```

## Understanding Key Concepts

### Pool Keys and Pool Identification

In Uniswap V4, pools are identified by a `PoolKey` struct. This is critical for all interactions with the pool.

A `PoolKey` consists of:
- Two tokens (currency0 and currency1, always ordered by address)
- A fee tier (e.g., 3000 for 0.3%)
- A tick spacing value
- Hooks address (can be zero address if no hooks)

### zeroForOne Explained

The `zeroForOne` parameter determines the direction of the swap:

- If `true`: You're swapping from currency0 to currency1
- If `false`: You're swapping from currency1 to currency0

This is important because:
1. Pools have a specific order of tokens (currency0 and currency1)
2. The user's selected input/output tokens might not match this order
3. We need to determine if the user is swapping "with the pool direction" or "against it"

### Slippage Protection

Our implementation includes slippage protection by:
1. Getting estimated output amount first
2. Applying a slippage tolerance (e.g., 0.5%)
3. Setting a minimum output amount when executing the swap

### Price Calculation

The price in Uniswap V4 is represented as `sqrtPriceX96`, which is the square root of the price multiplied by 2^96.

Our `getAmountOut` function:
1. Gets the current `sqrtPriceX96` from the pool
2. Uses different calculation methods based on swap direction
3. Applies an approximation of the swap fee

## Testing

Run the tests with:
```
forge test -vvv
```

## License

MIT
