// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BookingContract {
    IERC20 public token;
    address public owner;
    uint16 public nextBookingId;

    //Constants
    uint256 private constant ONE_DAY = 1 days;
    uint256 private constant PAYMENT_DEADLINE_OFFSET = 1 days;
    uint256 private constant REFUND_OFFSET = 7 days;
    uint256 private constant SECONDS_IN_A_DAY = 86400;

    enum BookingStatus { Pending, Confirmed, Cancelled }
    enum PaymentMode { Token }
    enum RoomType { Standard, Deluxe, Suite }

    struct BookingCore {
        string customer;
        address customerAddress;
        uint256 baseAmount;
        uint8 taxPercentage;
        bool isRefundable;
        uint256 checkOutDate;
    }

    struct BookingDetails {
        uint256 disputeDeadline;
        address payer;
        RoomType roomType;
        BookingStatus status;
        uint256 paymentDeadline;
        uint256 confirmationTime;
    }

    struct Tax {
        uint8 percentage;
    }

    struct RoomPrices {
        uint128 standard;
        uint128 deluxe;
        uint128 suite;
    }

    mapping(uint16 => BookingCore) public bookingsCore;
    mapping(uint16 => BookingDetails) public bookingsDetails;
    Tax public tax;
    RoomPrices public roomPrices;

    event NewBooking(uint16 bookingId, string customer, uint256 amount);
    event PaymentReceived(uint16 bookingId, uint256 amount, PaymentMode mode);
    event RefundProcessed(uint16 bookingId, uint256 amount);
    event BookingCancelled(uint16 bookingId);
    event ProformaInvoice(uint16 bookingId, address customer, uint256 amountDue, uint256 paymentDeadline);
    event DisputeRaised(uint16 bookingId, address customer, string reason);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _tokenAddress) {
        owner = msg.sender;
        token = IERC20(_tokenAddress);
        
        roomPrices = RoomPrices({
            standard: 0.1 ether,
            deluxe: 0.2 ether,
            suite: 0.3 ether
        });
        
        tax = Tax({percentage: 5});
    }

    function createBooking(
        string calldata _customer,
        uint256 _checkOutDate,
        RoomType _roomType
    ) external {
        nextBookingId++;
        uint16 currentId = nextBookingId;
        
        _createBookingCore(currentId, _customer, _checkOutDate, _roomType);
        _createBookingDetails(currentId, _checkOutDate, _roomType);

        emit NewBooking(currentId, _customer, getRoomPrice(_roomType));
    }

    function _createBookingCore(
        uint16 _bookingId,
        string calldata _customer,
        uint256 _checkOutDate,
        RoomType _roomType
    ) private {
        bookingsCore[_bookingId] = BookingCore({
            customer: _customer,
            customerAddress: msg.sender,
            baseAmount: getRoomPrice(_roomType),
            taxPercentage: tax.percentage,
            isRefundable: false,
            checkOutDate: _checkOutDate
        });
    }

    function _createBookingDetails(
        uint16 _bookingId,
        uint256 _checkOutDate,
        RoomType _roomType
    ) private {
        bookingsDetails[_bookingId] = BookingDetails({
            disputeDeadline: _checkOutDate + ONE_DAY,
            payer: address(0),
            roomType: _roomType,
            status: BookingStatus.Pending,
            paymentDeadline: block.timestamp + PAYMENT_DEADLINE_OFFSET,
            confirmationTime: 0
        });
    }

    function confirmBooking(uint16 _bookingId) external {
        BookingCore storage bookingCore = bookingsCore[_bookingId];
        BookingDetails storage bookingDetails = bookingsDetails[_bookingId];
        
        require(bookingCore.customerAddress == msg.sender, "Not customer");
        require(bookingDetails.status == BookingStatus.Pending, "Invalid status");

        bookingDetails.status = BookingStatus.Confirmed;
        bookingDetails.paymentDeadline = block.timestamp + PAYMENT_DEADLINE_OFFSET;
        bookingDetails.confirmationTime = block.timestamp;

        uint256 totalAmount = calculateTotalAmount(bookingCore.baseAmount, bookingCore.taxPercentage);
        
        emit ProformaInvoice(
            _bookingId,
            bookingCore.customerAddress,
            totalAmount,
            bookingDetails.paymentDeadline
        );
    }

    function calculateTotalAmount(uint256 baseAmount, uint8 taxPercent) public pure returns (uint256) {
        return (baseAmount * (100 + taxPercent)) / 100;
    }

    function payForBooking(uint16 _bookingId) external {
        BookingCore storage bookingCore = bookingsCore[_bookingId];
        BookingDetails storage bookingDetails = bookingsDetails[_bookingId];
        
        require(bookingDetails.status == BookingStatus.Confirmed, "Not confirmed");
        require(block.timestamp <= bookingDetails.paymentDeadline, "Deadline passed");

        uint256 totalAmount = calculateTotalAmount(bookingCore.baseAmount, bookingCore.taxPercentage);
        
        token.transferFrom(msg.sender, address(this), totalAmount);
        bookingDetails.payer = msg.sender;
        
        emit PaymentReceived(_bookingId, totalAmount, PaymentMode.Token);
    }

    function cancelBooking(uint16 _bookingId) external {
        BookingDetails storage bookingDetails = bookingsDetails[_bookingId];
        
        require(bookingDetails.status == BookingStatus.Confirmed, "Not confirmed");
        require(block.timestamp > bookingDetails.paymentDeadline, "Deadline not reached");

        bookingDetails.status = BookingStatus.Cancelled;
        emit BookingCancelled(_bookingId);
    }

    function refund(uint16 _bookingId) external {
        BookingCore storage bookingCore = bookingsCore[_bookingId];
        BookingDetails storage bookingDetails = bookingsDetails[_bookingId];
        
        require(bookingCore.isRefundable, "Not refundable");
        require(
            block.timestamp >= bookingCore.checkOutDate + REFUND_OFFSET,
            "Too early"
        );
        require(bookingDetails.payer == msg.sender, "Not payer");

        token.transfer(msg.sender, bookingCore.baseAmount);
        emit RefundProcessed(_bookingId, bookingCore.baseAmount);
    }

    function raiseDispute(uint16 _bookingId, string calldata _reason) external {
        BookingCore storage bookingCore = bookingsCore[_bookingId];
        BookingDetails storage bookingDetails = bookingsDetails[_bookingId];
        
        require(bookingCore.customerAddress == msg.sender, "Not customer");
        require(
            block.timestamp >= bookingDetails.confirmationTime &&
            (block.timestamp / SECONDS_IN_A_DAY) == (bookingDetails.confirmationTime / SECONDS_IN_A_DAY),
            "Invalid time"
        );

        emit DisputeRaised(_bookingId, msg.sender, _reason);
    }

    function modifyRefundableStatus(uint16 _bookingId) external onlyOwner {
        bookingsCore[_bookingId].isRefundable = !bookingsCore[_bookingId].isRefundable;
    }

    function setTaxPercentage(uint8 _percentage) external onlyOwner {
        tax.percentage = _percentage;
    }

    function setRoomPrices(
        uint128 _standardPrice,
        uint128 _deluxePrice,
        uint128 _suitePrice
    ) external onlyOwner {
        roomPrices = RoomPrices({
            standard: _standardPrice,
            deluxe: _deluxePrice,
            suite: _suitePrice
        });
    }

    function getRoomPrice(RoomType _roomType) public view returns (uint256) {
        if (_roomType == RoomType.Standard) return roomPrices.standard;
        if (_roomType == RoomType.Deluxe) return roomPrices.deluxe;
        return roomPrices.suite;
    }

    function getTaxPercentage() public view returns(uint256) {
        return tax.percentage;
    }
}