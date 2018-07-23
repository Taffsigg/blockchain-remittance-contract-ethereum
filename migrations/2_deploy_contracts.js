const RemittanceFactory = artifacts.require("./RemittanceFactory.sol");
const Remittance = artifacts.require("./Remittance.sol");
const RemittanceLib = artifacts.require("./RemittanceLib.sol");

module.exports = function(deployer) {
  deployer.deploy(RemittanceLib);
  deployer.link(RemittanceLib, Remittance);
  deployer.deploy(Remittance);
  deployer.deploy(RemittanceFactory, Remittance.address);
};
