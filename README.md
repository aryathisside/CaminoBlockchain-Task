# Booking Contract

## Overview

The **Booking Contract** is a smart contract built on the Ethereum blockchain that facilitates room bookings, payments, refunds, and dispute management. This contract allows users to create bookings, pay using ERC20 tokens, and manage their reservations while adhering to defined rules and conditions.

## Features

- **Booking Creation**: Customers can create bookings with specified checkout dates and room types.
- **Payment Processing**: Allows customers to pay for their bookings using an ERC20 token.
- **Refund Management**: Customers can request refunds if their bookings are refundable and meet specific conditions.
- **Dispute Management**: Customers can raise disputes related to their bookings within a specified timeframe.
- **Owner Controls**: The contract owner can set tax percentages and modify room prices.

## Smart Contract Details

### Prerequisites

- Solidity version: `^0.8.0`
- OpenZeppelin Contracts library for ERC20 token interactions.

### Data Structures

1. **Enums**:
   - `BookingStatus`: Represents the status of a booking (Pending, Confirmed, Cancelled).
   - `PaymentMode`: Represents the payment modes (currently only Token).
   - `RoomType`: Defines the types of rooms available (Standard, Deluxe, Suite).

2. **Structs**:
   - `BookingCore`: Contains core details of a booking, including the customer name, base amount, tax percentage, and refund status.
   - `BookingDetails`: Holds details about the booking status, payment information, and deadlines.
   - `Tax`: Holds the tax percentage for the bookings.
   - `RoomPrices`: Stores the prices for different room types.

### Functions

- `constructor(address _tokenAddress)`: Initializes the contract with the provided ERC20 token address and sets the default room prices and tax percentage.
- `createBooking(string calldata _customer, uint256 _checkOutDate, RoomType _roomType)`: Allows customers to create a new booking.
- `confirmBooking(uint16 _bookingId)`: Confirms a booking and sets the payment deadline.
- `payForBooking(uint16 _bookingId)`: Processes the payment for a confirmed booking.
- `cancelBooking(uint16 _bookingId)`: Cancels a confirmed booking after the payment deadline.
- `refund(uint16 _bookingId)`: Processes a refund for a booking if conditions are met.
- `raiseDispute(uint16 _bookingId, string calldata _reason)`: Allows customers to raise a dispute for their booking.
- `modifyRefundableStatus(uint16 _bookingId)`: Toggles the refundable status of a booking (only callable by the owner).
- `setTaxPercentage(uint8 _percentage)`: Allows the owner to set the tax percentage for bookings.
- `setRoomPrices(uint128 _standardPrice, uint128 _deluxePrice, uint128 _suitePrice)`: Allows the owner to set room prices.
- `getRoomPrice(RoomType _roomType)`: Returns the price of the specified room type.
- `getTaxPercentage()`: Returns the current tax percentage.

### Events

- `NewBooking`: Emitted when a new booking is created.
- `PaymentReceived`: Emitted when payment for a booking is received.
- `RefundProcessed`: Emitted when a refund is processed.
- `BookingCancelled`: Emitted when a booking is cancelled.
- `ProformaInvoice`: Emitted when a proforma invoice is issued.
- `DisputeRaised`: Emitted when a dispute is raised.

## Deployment

To deploy the contract, you will need to provide the address of the ERC20 token that will be used for payments.

**Token Address**
0x2cd428b370b29cde70a7aed221877824603d780c

**Booking Contract Address**
0x002Fe181e6212aa0064A40DBe34D52304622f697