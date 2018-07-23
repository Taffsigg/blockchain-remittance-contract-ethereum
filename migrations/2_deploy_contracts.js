const Remittance = artifacts.require("./Remittance.sol");
const RemittanceLib = artifacts.require("./RemittanceLib.sol");

module.exports = function(deployer) {
  deployer.deploy(RemittanceLib);
  deployer.deploy(Remittance);
  deployer.link(RemittanceLib, Remittance);
};
