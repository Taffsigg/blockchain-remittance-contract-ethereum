const Remittance = artifacts.require("./Remittance.sol");
const BigNumber = require('bignumber.js');
const Promise = require('bluebird');
const abi = require('ethereumjs-abi')

contract('Remittance', function(accounts) {

  Promise.promisifyAll(web3.eth, { suffix: "Promise" });
  
  const expectedExceptionPromise = require("./expected_exception_ganache_and_geth.js");  
  const gasPrice = 100000000000;
  const totalAmount = 1000000000000000;
  const daysClaim = 10;

  const alice = accounts[0];
  const carol = accounts[1];
  const bob = accounts[2];

  const passwordCarol = "p1";
  const passwordBob = "p2";
    
  let remittance;

  function getGasUsedInWei(txObj) {
    return gasPrice * txObj.receipt.gasUsed;
  }
  
  function getContractBalance() {
      return web3.eth.getBalancePromise(remittance.address);
  }

  function getKeccak256(address, password) {
    /**
     * web3utils keccak256 can't seem to calculate the hash 
     * based on three inputs (At least I couldn't get the 
     * same results with solidity and web3.utils.keccak256). I found
     * a reference here that talks about the issue:
     * https://github.com/ethereum/web3.js/issues/445
     */
    return "0x" + abi.soliditySHA3(
      [ "address", "string"],
      [  address,  password]).toString('hex')
  }

  beforeEach("should deploy a new instance", function() {
    return Remittance.new({ from: carol })
        .then(instance => remittance = instance);
  });

  describe("Deactivate a contract", function() {
    it("should allow the deactivation of an active contract", function() {
      return remittance.deactivate({ from: carol })
        .then(function(txObj) {
        assert.strictEqual(txObj.logs[0].event, "DeactivateContract");
        assert.strictEqual(txObj.logs[0].args.owner, carol);
      });
    });

    it("should allow the activation of an inactive contract", function() {
      return remittance.deactivate({ from: carol })
        .then(function() {
        return remittance.activate({ from: carol });
        }).then(function(txObj) {
          assert.strictEqual(txObj.logs[0].event, "ActivateContract");
        // Check that the owner really activated it, not somebody else
        assert.strictEqual(txObj.logs[0].args.owner, carol);
      });
    });

  });

  describe("Sending the money", function() {
    it("should generate an error when trying to do send money on a deactivated contract", function() {
      return remittance.deactivate({ from: carol })
        .then(function() {
        return expectedExceptionPromise(function () {
          return remittance.sendMoney("some unimportant hash",  daysClaim, 
            {from: alice, value: totalAmount, gasPrice: gasPrice});
        });
      });
    });

    it("should send " + totalAmount + " wei to the Remittance contract", function() {
      let balanceBefore;
      return getContractBalance()
        .then(function (balance) {
        balanceBefore = balance;
        return remittance.sendMoney("some unimportant hash", daysClaim,
          {from: alice, value: totalAmount, gasPrice: gasPrice});
      }).then(function (txObj) {
        assert.strictEqual(txObj.logs[0].event, "MoneySent");
        assert.strictEqual(txObj.logs[0].args.sender, alice);
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
    it("should allow claim back by original sender Alice", function() {
      let balanceBefore;
      return remittance.sendMoney("hash1",  daysClaim, 
        {from: alice, value: totalAmount, gasPrice: gasPrice})
        .then(function () {
          return getContractBalance();
      }).then(function (balance) {
        balanceBefore = balance;
        return remittance.claimBack("hash1", {from: alice, gasPrice: gasPrice});
      }).then(function (txObj) {
        assert.strictEqual(txObj.logs[0].event, "MoneyClaimedBack");
        assert.strictEqual(txObj.logs[0].args.originalSender, alice);
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
      return remittance.sendMoney("hash1",  daysClaim, 
        {from: alice, value: totalAmount, gasPrice: gasPrice})
      .then(function (balance) {
        return expectedExceptionPromise(function () {
          return remittance.claimBack("hash1", {from: carol, gasPrice: gasPrice});
        });
      });
    });

    it("should not allow claim back twice", function() {
      return remittance.sendMoney("hash1",  daysClaim, 
        {from: alice, value: totalAmount, gasPrice: gasPrice})
      .then(function () {
        return remittance.claimBack("hash1", {from: alice, gasPrice: gasPrice});
      }).then(function () {
        return expectedExceptionPromise(function () {
          return remittance.claimBack("hash1", {from: carol, gasPrice: gasPrice});
        });
      });
    });

    it("should allow claim back within deadline", function() {
      /** How to test this ? Usually mocking frameworks help here where 
       * the now function would be mocked with a dummy function **/
    });

    it("should not allow claim back after deadline", function() {
      /** How to test this ? Usually mocking frameworks help here where 
       * the now function would be mocked with a dummy function **/
    });

  });

  describe("Withdrawing", function() {

    it("should allow the withdrawl of " + totalAmount + " Carol", function() {
      let balanceBeforeCarol;
      let contractBalanceBefore;
      let txObj;
      remittanceHash = getKeccak256(carol, passwordBob);
      return remittance.sendMoney(remittanceHash, daysClaim,
        {from: alice, value: totalAmount, gasPrice: gasPrice})
      .then(function () {
        return getContractBalance();
      }).then(function (balance) {
        contractBalanceBefore = balance;
        return web3.eth.getBalancePromise(carol);
      }).then(function (balance) {
        balanceBeforeCarol = balance;
        return remittance.withdraw(passwordBob, {from: carol, gasPrice: gasPrice});
      }).then(function (_txObj) {
        txObj = _txObj
        assert.strictEqual(txObj.logs[0].event, "MoneyWithdrawnBy");
        assert.strictEqual(txObj.logs[0].args.receiver, carol);
        assert.strictEqual(txObj.logs[0].args.amount.toString(10), totalAmount.toString(10));
        return web3.eth.getBalancePromise(carol);
      }).then(function (balance) {
        balanceAfter = balance;
        return getContractBalance();
      }).then(function (balance) {
        contractBalanceAfter = balance;
        assert.strictEqual(
          new BigNumber(balanceBeforeCarol).plus(new BigNumber(totalAmount)).toString(10), 
          new BigNumber(balanceAfter).plus(new BigNumber(getGasUsedInWei(txObj))).toString(10), 
          "Carol did not withdraw " + totalAmount.toString(10));
        assert.strictEqual(
          new BigNumber(contractBalanceAfter).plus(new BigNumber(totalAmount)).toString(10), 
          new BigNumber(contractBalanceBefore).toString(10), 
          "Contract balance was not reduced by " + totalAmount.toString(10));
        });
    });

    it("should not allow the withdrawl of " + totalAmount + 
       " by Carol with an incorrect password of Bob", function() {
      remittanceHash = getKeccak256(carol, "passwordBobNotCorrect");
      return remittance.sendMoney(remittanceHash, daysClaim,
        {from: bob, value: totalAmount, gasPrice: gasPrice})
      .then(function () {
        return expectedExceptionPromise(function () {
          return remittance.withdraw(passwordBob, {from: bob, gasPrice: gasPrice});
        });
      });
    });

    it("should not allow the withdrawl of " + totalAmount + " by Bob", function() {
      remittanceHash = getKeccak256(carol, passwordBob);
      return remittance.sendMoney(remittanceHash, daysClaim,
        {from: alice, value: totalAmount, gasPrice: gasPrice})
      .then(function () {
        return web3.eth.getBalancePromise(carol);
      }).then(function () {
        return expectedExceptionPromise(function () {
          return remittance.withdraw(passwordBob, {from: bob, gasPrice: gasPrice});
        });
      });
    });

    it("should not allow a double withdrawl of " + totalAmount + " by Carol", function() {
      remittanceHash = getKeccak256(carol, passwordBob);
      return remittance.sendMoney(remittanceHash, daysClaim,
          {from: alice, value: totalAmount, gasPrice: gasPrice})
      .then(function () {
        return remittance.withdraw(passwordBob, {from: carol, 
          gasPrice: gasPrice});
      }).then(function (_txObj) {
        return expectedExceptionPromise(function () {
          return remittance.withdraw(passwordBob,  {from: carol, gasPrice: gasPrice});
        });
      });
    });

  });

  describe("Remittance as a service", function() {

    it("should allow two remittance processes simultaneously", function() {
      remittanceHash1 = getKeccak256(carol, passwordBob);
      return remittance.sendMoney(remittanceHash1, daysClaim,
        {from: alice, value: totalAmount, gasPrice: gasPrice})
      .then(function () {
        remittanceHash2 = getKeccak256(bob, passwordCarol);
        return remittance.sendMoney(remittanceHash2, daysClaim,
          {from: alice, value: totalAmount, gasPrice: gasPrice})
      }).then(function () {
        return getContractBalance();
      }).then(function (balance) {
        contractBalance = balance;
        assert.strictEqual(
          new BigNumber(contractBalance).toString(10), 
          new BigNumber(totalAmount).multipliedBy(2).toString(10),
          "Carol did not withdraw " + totalAmount.toString(10));
        return remittance.withdraw(passwordBob, {from: carol, gasPrice: gasPrice});
      }).then(function (j) {
        return remittance.withdraw(passwordCarol, {from: bob, gasPrice: gasPrice});
      }).then(function (j) {
        return getContractBalance();
      }).then(function (balance) {
        contractBalance = balance;
        assert.strictEqual(
          new BigNumber(contractBalance).toString(10), "0",
          "Bob did not withdraw " + totalAmount.toString(10));
      });
    });

  });

});
