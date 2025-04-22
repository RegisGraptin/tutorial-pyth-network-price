// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

import {console} from "forge-std/console.sol";


contract MyNFT {

    uint256 immutable PRICE_PRECISION = 1e18;

    uint256 immutable ETH_DECIMALS = 1e18;
    uint256 immutable USDC_DECIMALS = 1e6;

    uint256 immutable TOKEN_PRICE_USDC = 100 * USDC_DECIMALS;

    IPyth pyth;
    bytes32 ethUsdPriceId;

    // Error raised if the payment is not sufficient
    error InsufficientFee();
 
    constructor(address _pyth, bytes32 _ethUsdPriceId) {
        pyth = IPyth(_pyth);
        ethUsdPriceId = _ethUsdPriceId;
    }

    function buy() public payable {
        
        PythStructs.Price memory price = pyth.getPriceNoOlderThan(
            ethUsdPriceId,
            60  // in seconds
        );
    
        // Compute the expected number of wei for the given price
        uint256 ethUsdPrice = (uint256(uint64(price.price)) * PRICE_PRECISION) / (10 ** uint8(uint32(-price.expo)));
        uint256 requiredWeiPayment = (TOKEN_PRICE_USDC * ETH_DECIMALS * PRICE_PRECISION) / (ethUsdPrice * USDC_DECIMALS);

        if (msg.value < requiredWeiPayment) revert InsufficientFee();

        // Send a NFT for the user...

    }

    function updateAndBuy(bytes[] calldata pythPriceUpdate) external payable {
        uint256 updateFee = pyth.getUpdateFee(pythPriceUpdate);
        pyth.updatePriceFeeds{ value: updateFee }(pythPriceUpdate);
    
        buy();
    }
}
