pragma solidity ^0.4.24;

import "./Pausible.sol";

/*
Remittance contract. 
*/
contract Remittance is Pausible {

    event MoneySent(address sender, uint amount);
    event MoneyWithdrawnBy(address receiver, uint amount);
    event ContractCreated(address owner);
    event MoneyClaimedBack(address originalSender);
    
    uint constant public maxSecondsClaimBack = 2592000;   

    struct RemittanceData {
        address sender;
        uint balance;
        uint deadline;
    }

    /**
     * Mapping of the result of Keccak256(recipient, passwordBob) to 
     * the remittance data. This Keccak256 hash will be generated outside of
     * the contract by Alice based on the account address of Carol and 
     * Bob's passwords. 
     **/
    mapping(bytes32 => RemittanceData) public remittances;

    /**
     * This constructor creates an instance of the Remittance contract.  
     **/
    constructor() public {
        emit ContractCreated(owner);
    }

    /**
     * This function sends money to the remittance contract. It accept the
     * remittance hash that Alice must generate outside of the contract by calling
     * the getKeccak256 function. This hash will be generated by the applicaton 
     * that calls this function.
     **/
    function sendMoney(
            bytes32 remittanceHash, uint secondsClaimBack)  public payable onlyWhenActive {
                
        require(secondsClaimBack <= maxSecondsClaimBack, "Seconds claim back must be between 1 and 2592000");
        require(secondsClaimBack > 0, "Seconds claim back must be between 1 and 2592000");
        require(msg.value > 0, "Value sent must be greater than 0");
        require(remittanceHash != 0x0, "Incorrect remittance hash");
        require(remittances[remittanceHash].sender == 0x0, "Remittance hash already used");
        remittances[remittanceHash].balance = msg.value;
        remittances[remittanceHash].sender = msg.sender;
        remittances[remittanceHash].deadline = now + (secondsClaimBack * 1 seconds);
        emit MoneySent(msg.sender, msg.value);

    }

    /**
     * Function that allows Carol to withdraw the balance in the remittance 
     * contract. Carol has to provide the password that Bob gave to her. 
     * It's OK for the password to be visible on the
     * blockchain by other people, even if the transaction might not have 
     * been mined. Because only Carol can withdraw the funds because her address
     * is mixed with the password when calling the keccak256 function. Neither Bob,
     * Alice or anybody else could snatch the funds before she could.
     **/
    function withdraw(string passwordBob) 
            public onlyWhenActive {

        bytes32 remittanceHash = getKeccak256(msg.sender, passwordBob);
        uint availableBalance = remittances[remittanceHash].balance;
        require(availableBalance != 0x0, 
            "Combination of passwords is not correct or no balance");
        require(now < remittances[remittanceHash].deadline, 
            "Deadline reached, funds not withdrawn");
        remittances[remittanceHash].balance = 0;
        emit MoneyWithdrawnBy(msg.sender, availableBalance);
        msg.sender.transfer(availableBalance);
        
    } 
 
    /**
     * Alice can claim back the funds after the deadline has been reached
     * by using Bob's password and Carol's address
     **/
    function claimBack(address carol, string passwordBob) 
        public payable onlyWhenActive {
        
        bytes32 remittanceHash = getKeccak256(carol, passwordBob);
        uint availableBalance = remittances[remittanceHash].balance;
        require(availableBalance != 0x0, 
            "Combination of passwords is not correct or no balance");
        require(now >= remittances[remittanceHash].deadline, 
            "Deadline not reached yet, funds not claimed back");
        remittances[remittanceHash].balance = 0;
        emit MoneyClaimedBack(msg.sender);
        msg.sender.transfer(availableBalance);
        
    }
    
    /**
     * Fallback function which shouldn't be used to send money to the contract,
     * so don't make it payable
     **/
    function() public {
        revert("Not implemented");
    }
    
    /**
     * Function that will be used both by the contract, as well as Alice
     * who will generate the hash based on bob's password and Carol's 
     * address, before calling the function sendMoney. 
     **/
    function getKeccak256(address _address, string passwordBob) 
        view public returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), _address, passwordBob));        
    }

}