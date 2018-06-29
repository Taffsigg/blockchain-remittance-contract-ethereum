const Remittance = artifacts.require("./Remittance.sol");
const BigNumber = require('bignumber.js');
const Promise = require('bluebird');

contract('Remittance', function(accounts) {

  Promise.promisifyAll(web3.eth, { suffix: "Promise" });
  
  const expectedExceptionPromise = require("./expected_exception_ganache_and_geth.js");  
  const gasPrice = 100000000000;
  const totalAmount = 10000000000000000;
  const splitAmount = 4000000000000000;
  const daysClaim = 10;
  
  let remittance;

  function getGasUsedInWei(txObj) {
    return gasPrice * txObj.receipt.gasUsed;
  }
  
  function getContractBalance() {
      return web3.eth.getBalancePromise(remittance.address);
  }

  beforeEach("should deploy a new instance", function() {
    return Remittance.new({ from: accounts[0] })
        .then(instance => remittance = instance);
  });

  describe("Deactivate a contract", function() {
    it("should allow the deactivation of an active contract", function() {
      return remittance.deactivate({ from: accounts[0] })
        .then(function(txObj) {
        assert.strictEqual(txObj.logs[0].event, "DeactivateContract");
        assert.strictEqual(txObj.logs[0].args.owner, accounts[0]);
      });
    });

    it("should allow the activation of an inactive contract", function() {
      return remittance.deactivate({ from: accounts[0] })
        .then(function() {
        return remittance.activate({ from: accounts[0] });
        }).then(function(txObj) {
          assert.strictEqual(txObj.logs[0].event, "ActivateContract");
        // Check that the owner really activated it, not somebody else
        assert.strictEqual(txObj.logs[0].args.owner, accounts[0]);
      });
    });

  });

  describe("Sending the money", function() {
    it("should generate an error when trying to do send money on a deactivated contract", function() {
      return remittance.deactivate({ from: accounts[0] })
        .then(function() {
        return expectedExceptionPromise(function () {
          return remittance.sendMoney("password1", "password2", accounts[1], "1",  daysClaim, 
            {from: accounts[0], value: totalAmount, gasPrice: gasPrice});
        });
      });
    });

    it("should send {totalAmount} wei to the Remittance contract", function() {
      let balanceBefore;
      return getContractBalance()
        .then(function (balance) {
        balanceBefore = balance;
        return remittance.sendMoney("password1", "password2", accounts[1], "1",  daysClaim, 
        {from: accounts[0], value: totalAmount, gasPrice: gasPrice});
      }).then(function (txObj) {
        assert.strictEqual(txObj.logs[0].event, "MoneySent");
        assert.strictEqual(txObj.logs[0].args.sender, accounts[0]);
        assert.strictEqual(txObj.logs[0].args.amount.toString(10), totalAmount.toString(10));
        return getContractBalance();
      }).then(function (balance) {
        let balanceAfter = balance;
        assert.strictEqual
          (totalAmount.toString(10),
          new BigNumber(balanceAfter).minus(new BigNumber(balanceBefore)).toString(10), 
            totalAmount.toString(10) + " wasn't in the Remittance contract" + balanceAfter);
      });
    });
  });

  describe("Claiming back", function() {
    it("should allow claim back by original sender", function() {
      let balanceBefore;
      return remittance.sendMoney("password1", "password2", accounts[1], "1",  daysClaim, 
        {from: accounts[0], value: totalAmount, gasPrice: gasPrice})
        .then(function () {
          return getContractBalance();
      }).then(function (balance) {
        balanceBefore = balance;
        console.log("fsdfsdfdsf");
        return remittance.claimBack("1", {from: accounts[0], gasPrice: gasPrice});
      }).then(function (txObj) {
        assert.strictEqual(txObj.logs[0].event, "MoneyClaimedBack");
        assert.strictEqual(txObj.logs[0].args.originalSender, accounts[0]);
        return getContractBalance();
      }).then(function (balance) {
        let balanceAfter = balance;
        assert.strictEqual
          (totalAmount.toString(10),
          new BigNumber(balanceBefore).minus(new BigNumber(balanceAfter)).toString(10), 
            totalAmount.toString(10) + " wasn't claimed back from the Remittance contract");
      });
    });

    it("should not allow claim back by other person", function() {
      let balanceBefore;
      return remittance.sendMoney("password1", "password2", accounts[1], "1",  daysClaim, 
        {from: accounts[0], value: totalAmount, gasPrice: gasPrice})
        .then(function () {
        return getContractBalance();
      }).then(function (balance) {
        return expectedExceptionPromise(function () {
          return remittance.claimBack("1", {from: accounts[1], gasPrice: gasPrice});
        });
      });
    });
  });

});
