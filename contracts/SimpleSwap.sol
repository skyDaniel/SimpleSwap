// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ISimpleSwap } from "./interface/ISimpleSwap.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "hardhat/console.sol"; // for debugging usage

contract SimpleSwap is ISimpleSwap, ERC20 {
    // Implement core logic here

    ERC20 private _tokenA;
    ERC20 private _tokenB;

    uint256 private _reserveA;
    uint256 private _reserveB;

    constructor(address tokenA, address tokenB) ERC20("SimpleSwap", "SS") {
        require(tokenA != address(0), "SimpleSwap: TOKENA_IS_NOT_CONTRACT");
        require(tokenB != address(0), "SimpleSwap: TOKENB_IS_NOT_CONTRACT");
        require(tokenA != tokenB, "SimpleSwap: TOKENA_TOKENB_IDENTICAL_ADDRESS");
        _tokenA = ERC20(tokenA);
        _tokenB = ERC20(tokenB);
    }

    /// @notice Swap tokenIn for tokenOut with amountIn
    /// @param tokenIn The address of the token to swap from
    /// @param tokenOut The address of the token to swap to
    /// @param amountIn The amount of tokenIn to swap
    /// @return amountOut The amount of tokenOut received
    function swap(address tokenIn, address tokenOut, uint256 amountIn) external returns (uint256 amountOut)
    {
        require(tokenIn == address(_tokenA) || tokenIn == address(_tokenB), "SimpleSwap: INVALID_TOKEN_IN");
        require(tokenOut == address(_tokenA) || tokenOut == address(_tokenB), "SimpleSwap: INVALID_TOKEN_OUT");
        require(tokenIn != tokenOut, "SimpleSwap: IDENTICAL_ADDRESS");
        require(amountIn != 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");


        uint originalReserveA = _reserveA;
        uint originalReserveB = _reserveB;
        uint originalK = originalReserveA * originalReserveB;

        // console.log("swap(): originalReserveA: %s, originalReserveB: %s", originalReserveA / 1e18, originalReserveB / 1e18);

        if (tokenIn == address(_tokenA)) {
            _reserveA += amountIn;
            _reserveB = (originalK + (_reserveA - 1)) / _reserveA; // round up for the division
            amountOut = originalReserveB - _reserveB;
        }
        else { // tokenIn == address(_tokenB)
            _reserveB += amountIn;
            _reserveA = (originalK + (_reserveB - 1)) / _reserveB; // round up for the division
            amountOut = originalReserveA - _reserveA;
        }

        // console.log("swap(): newReserveA: %s, newReserveB: %s", _reserveA / 1e18, _reserveB / 1e18);

        uint newK = _reserveA * _reserveB;
        require(amountOut != 0, "SimpleSwap: INSUFFICIENT_OUTPUT_AMOUNT");

        ERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        ERC20(tokenOut).transfer(msg.sender, amountOut);

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);

        
    }

    /// @notice Add liquidity to the pool
    /// @param amountAIn The amount of tokenA to add
    /// @param amountBIn The amount of tokenB to add
    /// @return amountA The actually amount of tokenA added
    /// @return amountB The actually amount of tokenB added
    /// @return liquidity The amount of liquidity minted
    function addLiquidity(uint256 amountAIn, uint256 amountBIn) external returns (uint256 amountA, uint256 amountB, uint256 liquidity)
    {
        require(amountAIn > 0 && amountBIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");
        uint originalReserveA = _reserveA;
        uint originalReserveB = _reserveB;

        uint originalTotalSupply = totalSupply();
        if (originalTotalSupply == 0) {
            // first time to add liquidity
            amountA = amountAIn;
            amountB = amountBIn;
            liquidity = sqrt(amountA * amountB);
        }
        else {
            if (amountAIn * originalReserveB <= amountBIn * originalReserveA) {
                amountA = amountAIn;
                amountB = amountAIn * originalReserveB / originalReserveA;
            }
            else { // (amountAIn * originalReserveB > amountBIn * originalReserveA)
                amountA = amountBIn * originalReserveA / originalReserveB;
                amountB = amountBIn;
            }
            liquidity = amountA * originalTotalSupply / originalReserveA;
            // liquidity = sqrt(amountA * amountB);
        }

        _reserveA += amountA;
        _reserveB += amountB;

        // console.log("amountA: %s", amountA);
        // console.log("amountB: %s", amountB);

        _tokenA.transferFrom(msg.sender, address(this), amountA);
        _tokenB.transferFrom(msg.sender, address(this), amountB);
        // console.log("originalReserveA: %s, originalReserveB: %s", originalReserveA / 1e18, originalReserveB / 1e18);
        // console.log("amountAIn: %s, amountBIn: %s, liquidity: %s", amountA / 1e18, amountB / 1e18, liquidity / 1e18);
        _mint(msg.sender, liquidity);
        emit AddLiquidity(msg.sender, amountA, amountB, liquidity);

    }

    /// @notice Remove liquidity from the pool
    /// @param liquidity The amount of liquidity to remove
    /// @return amountA The amount of tokenA received
    /// @return amountB The amount of tokenB received
    function removeLiquidity(uint256 liquidity) external returns (uint256 amountA, uint256 amountB)
    {
        uint originalReserveA = _reserveA;
        uint originalReserveB = _reserveB;
        uint originalTotalSupply = totalSupply();

        require(liquidity > 0 && liquidity <= originalTotalSupply, "SimpleSwap: INSUFFICIENT_LIQUIDITY_BURNED");

        amountA = originalReserveA * liquidity / originalTotalSupply;
        amountB = originalReserveB * liquidity / originalTotalSupply;

        _reserveA -= amountA;
        _reserveB -= amountB;

        _tokenA.transfer(msg.sender, amountA);
        _tokenB.transfer(msg.sender, amountB);
        
        transfer(address(this), liquidity); // tranfer SS token from msg.sender to address(this)
        _burn(address(this), liquidity);

        emit RemoveLiquidity(msg.sender, amountA, amountB, liquidity);
    }

    /// @notice Get the reserves of the pool
    /// @return reserveA The reserve of tokenA
    /// @return reserveB The reserve of tokenB
    function getReserves() external view returns (uint256 reserveA, uint256 reserveB)
    {
        return (_reserveA, _reserveB);
    }

    /// @notice Get the address of tokenA
    /// @return tokenA The address of tokenA
    function getTokenA() external view returns (address tokenA)
    {
        tokenA = address(_tokenA);
    }

    /// @notice Get the address of tokenB
    /// @return tokenB The address of tokenB
    function getTokenB() external view returns (address tokenB)
    {
        tokenB = address(_tokenB);
    }

    function max(uint x, uint y) internal pure returns (uint z) {
        z = x > y ? x : y;
    }

    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }

    // Copied from https://github.com/Uniswap/v2-core/blob/master/contracts/libraries/Math.sol
    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
