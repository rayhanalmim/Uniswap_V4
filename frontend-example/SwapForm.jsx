import React, { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import SwapperABI from '../abi/Swapper.json';
import ERC20ABI from '../abi/ERC20.json';

// Example component for a token swap interface
const SwapForm = ({ provider, swapperAddress }) => {
  const [inputAmount, setInputAmount] = useState('');
  const [outputAmount, setOutputAmount] = useState('');
  const [selectedTokenIn, setSelectedTokenIn] = useState(null);
  const [selectedTokenOut, setSelectedTokenOut] = useState(null);
  const [availableTokens, setAvailableTokens] = useState([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');
  
  // Simulated token list - in a real app, you'd fetch this from an API
  useEffect(() => {
    setAvailableTokens([
      { address: '0x1234...', symbol: 'TKNA', name: 'Token A', decimals: 18 },
      { address: '0x5678...', symbol: 'TKNB', name: 'Token B', decimals: 18 },
      { address: '0x9abc...', symbol: 'USDC', name: 'USD Coin', decimals: 6 },
      { address: '0xdef0...', symbol: 'WETH', name: 'Wrapped Ether', decimals: 18 }
    ]);
  }, []);

  // Create a pool key for the selected token pair
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
  
  // Check if the input token is currency0 in the pool
  const isZeroForOne = (tokenA, tokenB) => {
    return tokenA.address.toLowerCase() < tokenB.address.toLowerCase();
  };

  // Get estimated output amount when input amount changes
  useEffect(() => {
    const getEstimatedOutput = async () => {
      if (!inputAmount || !selectedTokenIn || !selectedTokenOut || !provider) {
        setOutputAmount('');
        return;
      }
      
      try {
        setIsLoading(true);
        setError('');
        
        const swapper = new ethers.Contract(swapperAddress, SwapperABI, provider);
        const poolKey = createPoolKey(selectedTokenIn, selectedTokenOut);
        const zeroForOne = isZeroForOne(selectedTokenIn, selectedTokenOut);
        
        // Convert input amount to proper decimals
        const amountIn = ethers.parseUnits(inputAmount, selectedTokenIn.decimals);
        
        // Call the getAmountOut function
        const estimatedOutput = await swapper.getAmountOut(
          poolKey,
          amountIn,
          zeroForOne
        );
        
        // Format the output amount based on token decimals
        const formattedOutput = ethers.formatUnits(estimatedOutput, selectedTokenOut.decimals);
        setOutputAmount(formattedOutput);
        
      } catch (err) {
        console.error('Error estimating output:', err);
        setError('Failed to estimate output amount');
        setOutputAmount('');
      } finally {
        setIsLoading(false);
      }
    };
    
    getEstimatedOutput();
  }, [inputAmount, selectedTokenIn, selectedTokenOut, provider, swapperAddress]);
  
  // Handle the swap execution
  const handleSwap = async () => {
    if (!inputAmount || !selectedTokenIn || !selectedTokenOut || !provider) {
      setError('Please fill all fields');
      return;
    }
    
    try {
      setIsLoading(true);
      setError('');
      
      const signer = provider.getSigner();
      const swapper = new ethers.Contract(swapperAddress, SwapperABI, signer);
      
      // Create the pool key
      const poolKey = createPoolKey(selectedTokenIn, selectedTokenOut);
      const zeroForOne = isZeroForOne(selectedTokenIn, selectedTokenOut);
      
      // Convert input amount to proper decimals
      const amountIn = ethers.parseUnits(inputAmount, selectedTokenIn.decimals);
      
      // Set slippage tolerance (e.g., 0.5%)
      const slippage = 0.005;
      const minAmountOut = ethers.parseUnits(
        (parseFloat(outputAmount) * (1 - slippage)).toFixed(selectedTokenOut.decimals),
        selectedTokenOut.decimals
      );
      
      // Approve tokens first
      const inputToken = new ethers.Contract(selectedTokenIn.address, ERC20ABI, signer);
      const approveTx = await inputToken.approve(swapperAddress, amountIn);
      await approveTx.wait();
      
      // Execute the swap
      const swapTx = await swapper.swapExactInputSingle(
        poolKey,
        amountIn,
        minAmountOut,
        zeroForOne
      );
      
      await swapTx.wait();
      alert('Swap completed successfully!');
      
    } catch (err) {
      console.error('Error executing swap:', err);
      setError(`Failed to execute swap: ${err.message}`);
    } finally {
      setIsLoading(false);
    }
  };
  
  return (
    <div className="swap-form">
      <h2>Swap Tokens</h2>
      
      <div className="input-group">
        <label>From</label>
        <select 
          value={selectedTokenIn?.address || ''}
          onChange={(e) => {
            const token = availableTokens.find(t => t.address === e.target.value);
            setSelectedTokenIn(token);
          }}
        >
          <option value="">Select token</option>
          {availableTokens.map((token) => (
            <option key={token.address} value={token.address}>
              {token.symbol} - {token.name}
            </option>
          ))}
        </select>
        
        <input 
          type="number" 
          value={inputAmount} 
          onChange={(e) => setInputAmount(e.target.value)}
          placeholder="0.0"
        />
      </div>
      
      <div className="arrow">↓</div>
      
      <div className="input-group">
        <label>To</label>
        <select 
          value={selectedTokenOut?.address || ''}
          onChange={(e) => {
            const token = availableTokens.find(t => t.address === e.target.value);
            setSelectedTokenOut(token);
          }}
        >
          <option value="">Select token</option>
          {availableTokens.map((token) => (
            <option key={token.address} value={token.address}>
              {token.symbol} - {token.name}
            </option>
          ))}
        </select>
        
        <input 
          type="text" 
          value={isLoading ? 'Calculating...' : outputAmount} 
          readOnly
          placeholder="0.0"
        />
      </div>
      
      {error && <div className="error">{error}</div>}
      
      <button 
        onClick={handleSwap} 
        disabled={isLoading || !inputAmount || !selectedTokenIn || !selectedTokenOut}
      >
        {isLoading ? 'Processing...' : 'Swap'}
      </button>
      
      {outputAmount && (
        <div className="rate-info">
          Rate: 1 {selectedTokenIn?.symbol} = {(parseFloat(outputAmount) / parseFloat(inputAmount)).toFixed(6)} {selectedTokenOut?.symbol}
        </div>
      )}
    </div>
  );
};

export default SwapForm; 