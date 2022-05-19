const hre = require("hardhat")

async function main() {

    // Make sure everything is compiled
    await run('compile')

    const KudosV3 = await hre.ethers.getContractFactory("KudosV3")

    console.log("Deploying...")

    const kudos = await KudosV3.deploy()

    console.log('KudosV3 deployed. Address:', kudos.address)
    console.log(`About the contract, see: https://polygonscan.com/address/${kudos.address}`)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })