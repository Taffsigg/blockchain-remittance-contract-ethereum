pragma solidity ^0.4.24;

contract RemittanceHeader {
    
    event MoneySent(address sender, uint amount);
    event MoneyWithdrawnBy(address receiver, uint amount);
    event ContractCreated(address owner);
    event MoneyClaimedBack(address originalSender);
    
}
