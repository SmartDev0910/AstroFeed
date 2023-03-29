async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const AstroFeed = await ethers.getContractFactory("AstroFeed");
  const astroFeed = await AstroFeed.deploy();

  console.log("AstroFeed address:", astroFeed.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
