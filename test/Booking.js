const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("BookingContract", function () {
  let bookingContract;
  let tokenContractAddress, bookingContractAddress;
  let txn, owner, customer, payer;

  beforeEach(async() => {
    [owner, customer, payer] = await ethers.getSigners();

    // Deploy ERC20 token for payment
    const Token = await ethers.getContractFactory("TestToken");
    tokenContract = await Token.deploy(ethers.parseEther("10000"));
    tokenContractAddress = await tokenContract.getAddress();

    txn = await tokenContract.connect(owner).mint(payer.address, ethers.parseEther("3000"));
    console.log(`tokenContractAddress: ${tokenContractAddress}`);

    // Deploy the Booking contract
    const BookingContract = await ethers.getContractFactory("BookingContract");
    bookingContract = await BookingContract.deploy(tokenContractAddress);
    bookingContractAddress = await bookingContract.getAddress();

    console.log(`bookingContractAddress: ${bookingContractAddress}`);
  });

  describe('Success', async() => { 
    let txn;
    beforeEach(async() =>{
      txn = await bookingContract.connect(customer).createBooking("John Doe", 1693459200, 0); //room type (0 = Standard)
      await txn.wait();
    })

    it("check creation of a booking", async () => {
      const bookingCore = await bookingContract.bookingsCore(1);
      const bookingDetails = await bookingContract.bookingsDetails(1);
      
      expect(bookingCore.customer).to.equal("John Doe");
      expect(bookingDetails.roomType).to.equal(0); // Standard
      expect(bookingDetails.status).to.equal(0); // Pending
      console.log("Here");
    });

    it("check booking confirmation", async () => {
      txn = await bookingContract.connect(customer).confirmBooking(1);
      await txn.wait();
      const bookingDetails = await bookingContract.bookingsDetails(1);
      expect(bookingDetails.status).to.equal(1); // Confirmed
    });

    it("Check payment for a booking", async function () {
      txn = await bookingContract.connect(customer).createBooking("John ", 1693459800, 0);
      await txn.wait();
      txn = await bookingContract.connect(customer).confirmBooking(1);
      await txn.wait();

      const bookingCore = await bookingContract.bookingsCore(1);
      const totalAmount = await bookingContract.calculateTotalAmount(bookingCore.baseAmount, bookingCore.taxPercentage);

      console.log("paymentAmount", ethers.formatEther(totalAmount));

      txn = await tokenContract.connect(payer).approve(bookingContractAddress, totalAmount);
      await txn.wait();

      txn = await bookingContract.connect(payer).payForBooking(1);
      await txn.wait();

      const bookingDetails = await bookingContract.bookingsDetails(1);
      expect(bookingDetails.payer).to.equal(payer.address);

      const balanceOfPayer = await tokenContract.balanceOf(payer.address);
      console.log("Balance:", ethers.formatEther(balanceOfPayer));
    });

    it("Check cancel booking if payment deadline passed", async function () {
      txn = await bookingContract.connect(customer).createBooking("John Doe", 1693459200, 0);
      await txn.wait();
      txn = await bookingContract.connect(customer).confirmBooking(1);
      await txn.wait();

      await ethers.provider.send("evm_increaseTime", [24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      await bookingContract.cancelBooking(1);
      const bookingDetails = await bookingContract.bookingsDetails(1);
      expect(bookingDetails.status).to.equal(2); // Cancelled
    });

    it("Check rejection booking payment after deadline", async function () {
      txn = await bookingContract.connect(customer).createBooking("John Doe", 1693459200, 0);
      await txn.wait();
      txn = await bookingContract.connect(customer).confirmBooking(1);
      await txn.wait();

      await ethers.provider.send("evm_increaseTime", [24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      await expect(bookingContract.connect(payer).payForBooking(1)).to.revertedWith("Deadline passed");
    });

    it("Check refunds process for refundable bookings", async function () {
      txn = await bookingContract.connect(customer).createBooking("John Doe", 1693459200, 0);
      await txn.wait();
      txn = await bookingContract.connect(customer).confirmBooking(1);
      await txn.wait();

      txn = await bookingContract.connect(owner).modifyRefundableStatus(1);
      await txn.wait();

      const bookingCore = await bookingContract.bookingsCore(1);
      const totalAmount = await bookingContract.calculateTotalAmount(bookingCore.baseAmount, bookingCore.taxPercentage);
      
      console.log("paymentAmount", ethers.formatEther(totalAmount));
      
      txn = await tokenContract.connect(payer).approve(bookingContractAddress, totalAmount);
      await txn.wait();

      txn = await bookingContract.connect(payer).payForBooking(1);
      await txn.wait();

      await ethers.provider.send("evm_increaseTime", [7 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      txn = await bookingContract.connect(payer).refund(1);
      await txn.wait();
    });

    it("Check set the tax percentage", async function () {
      let newTax = 10;
      txn = await bookingContract.connect(owner).setTaxPercentage(newTax);
      await txn.wait();
      const tax = await bookingContract.getTaxPercentage();
      expect(tax).to.equal(newTax);
    });

    it("Check set room prices", async function () {
      let standardPrice = ethers.parseEther("0.5")
      let deluxePrice = ethers.parseEther("0.6")
      let suitePrice = ethers.parseEther("0.7")

      txn = await bookingContract.connect(owner).setRoomPrices(standardPrice, deluxePrice, suitePrice);
      await txn.wait();

      const roomPrices = await bookingContract.roomPrices();
      expect(roomPrices.standard).to.equal(standardPrice);
      expect(roomPrices.deluxe).to.equal(deluxePrice);
      expect(roomPrices.suite).to.equal(suitePrice);
    });
  });

  describe('Failure', () =>{
    let txn;
    beforeEach(async() =>{
      txn = await bookingContract.connect(customer).createBooking("John Doe", 1693459200, 0);
      await txn.wait();
    })

    it("check booking confirmation", async () => {
      await expect(bookingContract.connect(payer).confirmBooking(1)).to.revertedWith('Not customer');
    });

    it("Check refunds process for non-refundable bookings", async function () {
      txn = await bookingContract.connect(customer).confirmBooking(1);
      await txn.wait();

      const bookingCore = await bookingContract.bookingsCore(1);
      const totalAmount = await bookingContract.calculateTotalAmount(bookingCore.baseAmount, bookingCore.taxPercentage);
      
      txn = await tokenContract.connect(payer).approve(bookingContractAddress, totalAmount);
      await txn.wait();

      txn = await bookingContract.connect(payer).payForBooking(1);
      await txn.wait();

      await ethers.provider.send("evm_increaseTime", [7 * 24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine");

      await expect(bookingContract.connect(payer).refund(1)).to.revertedWith('Not refundable');
    });

    it("Check set the tax percentage by non-owner", async function () {
      await expect(bookingContract.connect(payer).setTaxPercentage(10)).to.revertedWith("Not owner");
    });

    it("Check set room prices by non-owner", async function () {
      let standardPrice = ethers.parseEther("0.5")
      let deluxePrice = ethers.parseEther("0.6")
      let suitePrice = ethers.parseEther("0.7")

      await expect(bookingContract.connect(payer).setRoomPrices(standardPrice, deluxePrice, suitePrice))
        .to.revertedWith("Not owner");
    });
  });
});