# Testing the Swapper Contract on Sepolia Testnet

This guide provides step-by-step instructions for deploying and testing the Swapper contract on the Sepolia testnet, which provides a more accurate testing environment compared to local mocks.

## Prerequisites

1. **Node.js and npm**: Make sure you have Node.js installed (v16+)
2. **Foundry**: Ensure you have Foundry installed (Forge, Cast, Anvil)
3. **Sepolia ETH**: You'll need some Sepolia ETH for gas (can be obtained from faucets)
4. **Private key**: A wallet private key for deployments

## Environment Setup

1. Create a `.env` file in the project root with the following content:

```
PRIVATE_KEY=your_private_key_here
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/your_infura_key_here
ETHERSCAN_API_KEY=your_etherscan_api_key_here
```

2. Install dependencies:

```bash
forge install
```

## Sepolia Testnet Deployments

For Uniswap V4, here are the key contract addresses on Sepolia:

- **Pool Manager**: `0x64255ed21366DB43d89736EE48928b890A84E2Cb`
- **Universal Router**: `0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD`  
- **Permit2**: `0x000000000022D473030F116dDEE9F6B43aC78BA3`

## Deployment Process

1. Deploy your own ERC20 test tokens for testing:

```bash
forge script script/DeployTestTokens.s.sol:DeployTestTokens --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast
```

2. Deploy the Swapper contract, which connects to the Uniswap V4 infrastructure:

```bash
forge script script/DeploySwapper.s.sol:DeploySwapper --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast
```

3. Take note of the deployed contract addresses from the console output.

## Testing on Sepolia

### 1. Initialize a Pool

Before you can swap tokens, you need to initialize a pool for your token pair:

```bash
cast send --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY <POOL_MANAGER_ADDRESS> "initialize(bytes32,uint160)" <POOL_KEY> <INITIAL_SQRT_PRICE>
```

Where:
- `<POOL_KEY>` is the PoolKey struct encoded as a bytes32 value
- `<INITIAL_SQRT_PRICE>` is the initial price (can use `79228162514264337593543950336` for 1:1 pricing)

### 2. Add Liquidity to the Pool

Add liquidity to your pool so swaps can execute:

```bash
# Example script to add liquidity (you'd need to create this)
forge script script/AddLiquidity.s.sol:AddLiquidity --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast
```

### 3. Test Swap Functionality

1. **Estimate amount out**:
   You can call the `getAmountOut` function to estimate the expected output amount:

```bash
cast call --rpc-url $SEPOLIA_RPC_URL <SWAPPER_ADDRESS> "getAmountOut((address,address,uint24,int24,address),uint128,bool)" "<TOKEN_A>,<TOKEN_B>,3000,60,0x0000000000000000000000000000000000000000" 1000000000000000000 true
```

2. **Execute a swap**:
   First, approve the token to be spent:

```bash
cast send --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY <TOKEN_ADDRESS> "approve(address,uint256)" <SWAPPER_ADDRESS> 1000000000000000000
```

   Then execute the swap:

```bash
cast send --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY <SWAPPER_ADDRESS> "swapExactInputSingle((address,address,uint24,int24,address),uint128,uint128,bool)" "<TOKEN_A>,<TOKEN_B>,3000,60,0x0000000000000000000000000000000000000000" 1000000000000000000 900000000000000000 true
```

## Troubleshooting

If you encounter issues during testing on Sepolia:

1. **Insufficient liquidity**: Ensure there is enough liquidity in the pool to execute swaps.
2. **Price slippage**: If prices have moved significantly, you might need to adjust your `minAmountOut` parameter.
3. **Gas issues**: Sepolia sometimes requires higher gas settings. Try increasing gas limit.
4. **RPC errors**: Consider using a different RPC provider if you experience timeouts or connection issues.
5. **Contract verification**: Verify your contracts on Sepolia Etherscan to make debugging easier.

## Monitoring and Debugging

1. Use Sepolia Etherscan to monitor transactions and contract interactions.
2. Use tools like Tenderly to debug failed transactions.
3. Add events to your contract to track important state changes and debug issues.

## Conclusion

Testing on Sepolia provides a much more realistic environment than local mocking. It allows you to interact with the actual Uniswap V4 infrastructure and verify that your contract will work correctly in production. While it requires more setup than local tests, it gives you much higher confidence in your code's production readiness.

For further questions or issues, please create a GitHub issue in this repository. 