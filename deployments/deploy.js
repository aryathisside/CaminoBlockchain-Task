const hre = require("hardhat")

async function main() {

    const Booking = await ethers.getContractFactory("Booking")
    const BookingContract = await Booking.deploy()

    const BookingContractAddress = await BookingContract.getAddress()
    console.log(`Deployed Voting Contract at: ${BookingContractAddress}\n`)

}


main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

