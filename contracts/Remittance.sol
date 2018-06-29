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
    
    uint constant public maxDaysClaimBack = 30;   

    struct RemittanceData {
        uint balance;
        address alice;
        address carol;
        uint deadline;
    }

    /**
     * Mapping of the result of Keccak256(password1, password2) to 
     * the remittance data
     * */
    mapping(bytes32 => RemittanceData) public remittances;

    /** Mapping of the hash of Alice's address and an remittance id she chooses
     * to the remittance hash. When claiming back the money, Alice shouldn't
     * have to provide both passwords again as it would only verify 
     * that she hasn't forgotten the passwords. Just calling the claimback 
     * function with the id (and implicitly her address)
     * should be enough to give her back the funds. The id is necessary because
     * this contract should be a service. Alice could particate in more than
     * one remittance (at the same time). So her address is not enough to
     * map uniquely to remittances. An extra unique id that she chooses 
     * suffices in that case */
    mapping(bytes32 => bytes32) public claimbacks;

    /**
     * This constructor creates an instance of the Remittance contract.  
     **/
    constructor() public {
        emit ContractCreated(owner);
    }

    /**
     * This function sends money to the remittance contract. It accept both 
     * Carol's and Bob's passwords, Carol's address, and id that uniquely 
     * identifies the remittance and the days within which the money can be 
     * claimed back by Alice. The id is necessary as indicated before. See 
     * comments of claimback mapping definition. Alice should give the
     * id to Carol. */
    function sendMoney(
            string passwordCarol, string passwordBob, address carol,
            string id, uint daysClaim)  
            public payable 
            onlyWhenActive {
                
        require(bytes(id).length != 0, "id must have at least one character");
        require(daysClaim <= maxDaysClaimBack, "Days claim back too high");
        require(daysClaim > 0, "Days claim back must be greater than 0");
        require(msg.value > 0, "Value sent must be greater than 0");
        bytes32 remittanceHash = 
            getKeccak256ForRemittance(passwordCarol, passwordBob, carol, id);
        require(remittances[remittanceHash].balance == 0x0, 
            "Combination of passwords and id already used before");
        bytes32 claimbackHash = getKeccak256ForClaimback(id);
        require(claimbacks[claimbackHash] == 0x0, 
            "Id already used for other remittance");
        remittances[remittanceHash].balance = msg.value;
        remittances[remittanceHash].alice = msg.sender;
        remittances[remittanceHash].carol = carol;
        remittances[remittanceHash].deadline = now + (24 * 60 * 60 * daysClaim);
        claimbacks[claimbackHash] = remittanceHash;
        emit MoneySent(msg.sender, msg.value);

    }

    /**
     * Function that allows Carol to withdraw the balance. Carol has to 
     * provide both her own password and the password that Bob gave to her.
     * She also has to provide the remittance id that Alice will give to her
     */
    function withdraw(string passwordCarol, string passwordBob, string id) 
            onlyWhenActive public {

        require(bytes(id).length != 0, "id must have at least one character");
        bytes32 remittanceHash = 
            getKeccak256ForRemittance(passwordCarol, passwordBob, 
                msg.sender, id);
        require(remittances[remittanceHash].balance != 0x0, 
            "Combination of password and/or id not correct or no balance");
        uint availableBalance = remittances[remittanceHash].balance;
        remittances[remittanceHash].balance = 0;
        emit MoneyWithdrawnBy(msg.sender, availableBalance);
        msg.sender.transfer(availableBalance);
        
    } 
 
    /**
     * Carol can claim back the funds before Carol has withdrawn it. Alice only
     * needs to provide the id of the remittance. 
     **/
    function claimBack(string id) public payable onlyWhenActive {
        
        require(bytes(id).length != 0, "id must have at least one character");
        bytes32 claimbackHash = getKeccak256ForClaimback(id);
        require(claimbacks[claimbackHash] != 0x0, 
            "Combination of id and address not correct or already claimed back");
        bytes32 remittanceHash = claimbacks[claimbackHash];
        require(remittances[remittanceHash].balance != 0x0, 
            "Remittance not accessible"); // Hack or appplication error ?
        require(now <= remittances[remittanceHash].deadline, 
            "Deadline reached, funds not claimed back");
        uint availableBalance = remittances[remittanceHash].balance;
        remittances[remittanceHash].balance = 0;
        claimbacks[claimbackHash] = 0x0;
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
    
    function getKeccak256ForRemittance(
        string passwordCarol, string passwordBob, address carol, string id) 
        pure private
        returns (bytes32) {
        return keccak256(abi.encodePacked(passwordCarol, passwordBob, id, carol));        
    }

    function getKeccak256ForClaimback(string id) 
        view private
        returns (bytes32) {
        return keccak256(abi.encodePacked(msg.sender, id));        
    }

}