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

    address user = address(0x123);
    
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
        vm.warp(2); // Increase the timestamp

        nft = new MyNFT(address(mockPyth), ETH_USD_PRICE_ID);

        // Compute the price needed
        expectedPriceInWei = (uint256(uint64(ETH_MOCK_PRICE)) * 1e18) / (10 ** uint8(uint32(-ETH_MOCK_EXPO)));
        expectedPriceInWei = (TOKEN_PRICE_USDC * ETH_DECIMALS * 1e18) / expectedPriceInWei; 
        expectedPriceInWei = expectedPriceInWei / 1e6;

        // Add some token to the user
        vm.deal(user, expectedPriceInWei);
    }

    function testBuy_RevertsIfUnderpaid() public {
        // Send slightly less than required
        vm.startPrank(user);
        vm.expectRevert(MyNFT.InsufficientFee.selector);
        nft.buy{value: expectedPriceInWei - 1}();
        vm.stopPrank();
    }

    function testBuy_SucceedsIfPaidEnough() public {
        vm.startPrank(user);

        nft.buy{value: expectedPriceInWei}(); // should not revert
        assertEq(nft.balanceOf(user), 1); // Should have mint 1 Token

        vm.stopPrank();
    }

    function testBuy_SucceedsRefund() public {
        vm.startPrank(user);

        vm.deal(user, expectedPriceInWei + 1000);
        
        nft.buy{value: expectedPriceInWei + 1000}();
        assertEq(nft.balanceOf(user), 1);
        assertEq(user.balance, 1000);  // Should refund the user

        vm.stopPrank();
    }

    function testUpdateAndBuy() public {
        vm.startPrank(user);

        bytes[] memory pythPriceUpdate = new bytes[](1);
        pythPriceUpdate[0] = mockPyth.createPriceFeedUpdateData(
            ETH_USD_PRICE_ID, 
            ETH_MOCK_PRICE + 1e9,  // 1602_73959552
            ETH_MOCK_CONF,
            ETH_MOCK_EXPO,
            ETH_MOCK_PRICE + 1e9,
            ETH_MOCK_CONF,
            uint64(block.timestamp)
        );
        nft.updateAndBuy{value: expectedPriceInWei}(pythPriceUpdate);

        assertEq(nft.balanceOf(user), 1); // Should have mint 1 Token

        vm.stopPrank();
    }

    function testRevertOnHighConfidence() public {
        vm.startPrank(user);
        
        bytes[] memory pythPriceUpdate = new bytes[](1);
        pythPriceUpdate[0] = mockPyth.createPriceFeedUpdateData(
            ETH_USD_PRICE_ID, 
            ETH_MOCK_PRICE, 
            ETH_MOCK_CONF * 1e3,
            ETH_MOCK_EXPO,
            ETH_MOCK_PRICE,
            ETH_MOCK_CONF * 1e3,
            uint64(block.timestamp)
        );

        vm.expectRevert();
        nft.updateAndBuy{value: expectedPriceInWei}(pythPriceUpdate);

        vm.stopPrank();
    }

}
