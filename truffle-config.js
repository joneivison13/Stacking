const path = require("path");
let HDWalletProvider = require("truffle-hdwallet-provider");


module.exports = {
  contracts_build_directory: path.join(__dirname, "client/src/contracts"),
  networks: {
    develop: {
      port: 7545,
      host: '127.0.0.1',
      network_id: '*'
    },
    kovan: {
      provider: function() 
      {
        return new HDWalletProvider("ece408d81a16976ba379f44692b72b18ccfd37b1e860b2b26ad7fbe62ad3a26b",
                                    "https://kovan.infura.io/v3/33e14e2ff03147fba2d29622f667a695");
      }, 
      network_id: 42
    }
  },
  compilers: {
    solc: {
      version: '^0.8.0'
    } 
  }
};
