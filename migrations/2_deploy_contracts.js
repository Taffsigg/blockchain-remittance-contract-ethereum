const RemittanceFactory = artifacts.require("./RemittanceFactory.sol");
const Remittance = artifacts.require("./Remittance.sol");
const RemittanceLib = artifacts.require("./RemittanceLib.sol");

module.exports = (deployer) => 
  deployer.deploy(RemittanceLib)
    .then( () => 
      deployer.link(RemittanceLib, Remittance))
    .then( () => 
      deployer.deploy(Remittance))
    .then( () => 
      Remittance.deployed())
    .then( (remittance) => 
      deployer.deploy(RemittanceFactory, remittance.address))
        
    