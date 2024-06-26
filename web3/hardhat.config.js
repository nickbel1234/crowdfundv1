require('dotenv').config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: '0.8.19',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  defaultNetwork: 'VitruveoMainnet',
  networks: {
    hardhat: {},
    VitruveoMainnet: {
      url: 'https://rpc.vitruveo.xyz/',
      accounts: [`0x${process.env.PRIVATE_KEY}`],
      chainId: 1490, // Toegevoegd chainId
    },
  },
};
