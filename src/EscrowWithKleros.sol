// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title EscrowWithKleros
 * @notice Escrow contract integrated with a Kleros-like arbitrator.
 * Funds are held in the contract and can only be sent to buyer or seller.
 */

interface IArbitrator {
    function createDispute(uint256 choices, bytes calldata extraData) external payable returns (uint256 disputeID);
}

interface IArbitrable {
    function rule(uint256 disputeID, uint256 ruling) external;
}

contract EscrowWithKleros is IArbitrable {
    enum Status { AWAITING_PAYMENT, AWAITING_DELIVERY, DISPUTED, RESOLVED }
    enum RulingOptions { NONE, REFUND_BUYER, PAY_SELLER }

    address public immutable buyer;
    address public immutable seller;
    uint256 public immutable amount; // escrowed amount (wei)

    IArbitrator public arbitrator;
    uint256 public disputeID;
    Status public status;
    bool public disputed;

    // Events
    event PaymentDeposited(address indexed buyer, uint256 amount);
    event DisputeRaised(address indexed raiser, uint256 disputeID);
    event RulingExecuted(uint256 ruling, address recipient, uint256 amount);

    // Only the buyer can call
    modifier onlyBuyer() {
        require(msg.sender == buyer, "Only buyer");
        _;
    }

    constructor(address _buyer, address _seller, address _arbitrator) payable {
        require(_buyer != address(0) && _seller != address(0), "Invalid parties");
        require(msg.value > 0, "Escrow requires payment");

        buyer = _buyer;
        seller = _seller;
        amount = msg.value;
        arbitrator = IArbitrator(_arbitrator);
        status = Status.AWAITING_DELIVERY;

         emit PaymentDeposited(_buyer, msg.value);
    }

    /// @notice Either buyer or seller can raise a dispute by paying arbitration fee
    function raiseDispute(bytes calldata extraData) external payable {
        require(msg.sender == buyer || msg.sender == seller, "Only buyer or seller");
        require(status == Status.AWAITING_DELIVERY, "Cannot dispute now");
        require(!disputed, "Already disputed");

        // Create dispute on arbitrator; arbitration fee passed as msg.value
        disputeID = arbitrator.createDispute{value: msg.value}(2, extraData);
        disputed = true;
        status = Status.DISPUTED;

        emit DisputeRaised(msg.sender, disputeID);
    }

    function confirmPayment() external {
    require(msg.sender == buyer, "Only buyer can confirm");
    require(status == Status.AWAITING_DELIVERY, "Not awaiting delivery");
    payable(seller).transfer(amount);
    status = Status.RESOLVED;
}


    /// @notice Called by arbitrator to resolve dispute
    function rule(uint256 _disputeID, uint256 _ruling) external override {
        require(msg.sender == address(arbitrator), "Only arbitrator");
        require(disputed, "No dispute");
        require(_disputeID == disputeID, "Invalid dispute ID");
        require(status == Status.DISPUTED, "Not in dispute");

        address recipient;
        if (_ruling == uint256(RulingOptions.REFUND_BUYER)) {
            recipient = buyer;
        } else if (_ruling == uint256(RulingOptions.PAY_SELLER)) {
            recipient = seller;
        } else {
            revert("Invalid ruling");
        }

        status = Status.RESOLVED;
        payable(recipient).transfer(amount);

        emit RulingExecuted(_ruling, recipient, amount);
    }

    /// @notice Receive fallback (for arbitrator refunds or incidental transfers)
    receive() external payable {}
}
