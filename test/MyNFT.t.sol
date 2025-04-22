// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MyNFT} from "../src/MyNFT.sol";

import "@pythnetwork/pyth-sdk-solidity/MockPyth.sol";

contract MyNFTTest is Test {
    
    MyNFT public nft;
    MockPyth public mockPyth;
    uint256 expectedPriceInWei;

    uint256 public constant TOKEN_PRICE_USDC = 100 * 1e6; // 100 USDC
    uint256 public constant ETH_DECIMALS = 1e18;

    bytes32 public constant ETH_USD_PRICE_ID = "0x1234";
    int64 public constant ETH_MOCK_PRICE = 159273959552;
    uint64 public constant ETH_MOCK_CONF = 112319875;
    int32 public constant ETH_MOCK_EXPO = -8;

    
    function setUp() public {
        mockPyth = new MockPyth(60, 1);
        
        bytes[] memory priceUpdateDataArray = new bytes[](1);
        priceUpdateDataArray[0] = mockPyth.createPriceFeedUpdateData(
            ETH_USD_PRICE_ID, 
            ETH_MOCK_PRICE, 
            ETH_MOCK_CONF,
            ETH_MOCK_EXPO,
            ETH_MOCK_PRICE,
            ETH_MOCK_CONF,
            uint64(block.timestamp)
        );
        mockPyth.updatePriceFeeds{value: 1}(priceUpdateDataArray);
            
        nft = new MyNFT(address(mockPyth), ETH_USD_PRICE_ID);

        // Compute the price needed
        expectedPriceInWei = (uint256(uint64(ETH_MOCK_PRICE)) * 1e18) / (10 ** uint8(uint32(-ETH_MOCK_EXPO)));
        expectedPriceInWei = (TOKEN_PRICE_USDC * ETH_DECIMALS * 1e18) / expectedPriceInWei; 
        expectedPriceInWei = expectedPriceInWei / 1e6;
    }

    function testBuy_RevertsIfUnderpaid() public {
        // Send slightly less than required
        vm.expectRevert(MyNFT.InsufficientFee.selector);
        nft.buy{value: expectedPriceInWei - 1}();
    }

    function testBuy_SucceedsIfPaidEnough() public {
        nft.buy{value: expectedPriceInWei}(); // should not revert
    }
}
