// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {OutcomeTokenFactory} from "../src/tokens/OutcomeTokenFactory.sol";
import {OutcomeToken} from "../src/tokens/OutcomeToken.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract OutcomeTokenFactoryTest is Test {
    OutcomeTokenFactory public factory;
    address public recipient = address(0xBEEF);

    function setUp() public {
        factory = new OutcomeTokenFactory();
        factory.setAuthorizedCaller(address(this));
    }

    function test_CreateToken() public {
        address token = factory.createToken(0, 0, "Yes", "YES", 100_000e18, recipient);
        assertNotEq(token, address(0), "Token should be deployed");
        assertEq(IERC20(token).balanceOf(recipient), 100_000e18, "Recipient should have full supply");
        assertEq(factory.tokenCount(), 1);
    }

    function test_CreateMultipleTokens() public {
        address t0 = factory.createToken(0, 0, "Team A", "TA", 50_000e18, recipient);
        address t1 = factory.createToken(0, 1, "Team B", "TB", 50_000e18, recipient);
        address t2 = factory.createToken(0, 2, "Draw", "DRAW", 50_000e18, recipient);

        assertNotEq(t0, t1);
        assertNotEq(t1, t2);
        assertNotEq(t0, t2);
        assertEq(factory.tokenCount(), 3);
    }

    function test_GetToken() public {
        address created = factory.createToken(1, 0, "Yes", "YES", 100_000e18, recipient);
        assertEq(factory.getToken(1, 0), created);
        assertEq(factory.getToken(1, 1), address(0)); // Not created
    }

    function test_RevertDuplicateToken() public {
        factory.createToken(0, 0, "Yes", "YES", 100_000e18, recipient);
        vm.expectRevert("Token already exists");
        factory.createToken(0, 0, "Yes2", "YES2", 100_000e18, recipient);
    }

    function test_TokenMetadata() public {
        address token = factory.createToken(0, 0, "My Outcome", "OUT", 1_000e18, recipient);
        OutcomeToken ot = OutcomeToken(token);
        assertEq(ot.name(), "My Outcome");
        assertEq(ot.symbol(), "OUT");
        assertEq(ot.decimals(), 18);
        assertEq(ot.totalSupply(), 1_000e18);
    }

    function test_PredictAddress() public {
        address predicted = factory.predictTokenAddress(0, 0, "Yes", "YES", 100_000e18, recipient);
        address actual = factory.createToken(0, 0, "Yes", "YES", 100_000e18, recipient);
        assertEq(predicted, actual, "Predicted address should match");
    }

    function test_DifferentMarketsSameOutcomeIndex() public {
        address t0 = factory.createToken(0, 0, "Yes", "YES", 100_000e18, recipient);
        address t1 = factory.createToken(1, 0, "Yes", "YES", 100_000e18, recipient);
        assertNotEq(t0, t1, "Different markets should produce different tokens");
    }
}
