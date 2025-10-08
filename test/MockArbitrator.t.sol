// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../src/EscrowWithKleros.sol";

contract MockArbitrator is IArbitrator {
    uint256 public lastDisputeID;
    uint256 public fee = 0.01 ether;

    function createDispute(uint256 /*choices*/, bytes calldata) external payable override returns (uint256 disputeID) {
        require(msg.value >= fee, "Arbitration fee not paid");
        lastDisputeID = block.timestamp;
        return lastDisputeID;
    }

    // Helper to simulate arbitrator calling back the escrow contract
    function giveRuling(EscrowWithKleros escrow, uint256 disputeId, uint256 ruling) external {
        escrow.rule(disputeId, ruling);
    }
}

contract EscrowWithKlerosTest is Test {
    EscrowWithKleros escrow;
    MockArbitrator mockArbitrator;
    address buyer = address(0xBEEF);
    address seller = address(0xCAFE);

    function setUp() public {
        vm.deal(buyer, 1 ether);
        vm.deal(seller, 1 ether);

        mockArbitrator = new MockArbitrator();

        vm.startPrank(buyer);
        escrow = new EscrowWithKleros{value: 0.002 ether}(buyer, seller, address(mockArbitrator));
        vm.stopPrank();
    }

    function testConfirmPaymentPaysSeller() public {
        vm.startPrank(buyer);
        escrow.confirmPayment();
        vm.stopPrank();

        assertEq(uint(escrow.status()), uint(EscrowWithKleros.Status.RESOLVED));
    }

    function testRaiseDisputeSetsDisputed() public {
        vm.startPrank(buyer);
        escrow.raiseDispute{value: 0.01 ether}("0x");
        vm.stopPrank();

        assertEq(uint(escrow.status()), uint(EscrowWithKleros.Status.DISPUTED));
    }

    function testRuleRefundBuyer() public {
        vm.startPrank(buyer);
        escrow.raiseDispute{value: 0.01 ether}("0x");
        vm.stopPrank();

        uint256 beforeBalance = buyer.balance;

        // Simulate arbitrator calling back via mock
        vm.prank(address(mockArbitrator));
        mockArbitrator.giveRuling(escrow, escrow.disputeID(), uint256(EscrowWithKleros.RulingOptions.REFUND_BUYER));

        assertEq(uint(escrow.status()), uint(EscrowWithKleros.Status.RESOLVED));
        assertGt(buyer.balance, beforeBalance);
    }

    function testRulePaySeller() public {
        vm.startPrank(buyer);
        escrow.raiseDispute{value: 0.01 ether}("0x");
        vm.stopPrank();

        uint256 before = seller.balance;

        // Simulate arbitrator calling back via mock
        vm.prank(address(mockArbitrator));
        mockArbitrator.giveRuling(escrow, escrow.disputeID(), uint256(EscrowWithKleros.RulingOptions.PAY_SELLER));

        assertEq(uint(escrow.status()), uint(EscrowWithKleros.Status.RESOLVED));
        assertGt(seller.balance, before);
    }
}
