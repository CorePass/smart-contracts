const corebc = require("@corepass/corebc");
const { runTestNode } = require("@corepass/ylem-scripts");

module.exports = (mode) =>
  mode === "test"
    ? runTestNode()
    : {
        provider: "http://localhost:8545",
        signers: corebc.Wallet.createRandom("ce"),
      };
