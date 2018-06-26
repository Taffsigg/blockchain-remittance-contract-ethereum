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
        uint deadline;
    }

    /** mapping of remittances with as key the hash. The address of the sender
     * could also have used. But this way, the sender would have had max 
     * only one remittance going on at the same time. Using the hash as a key
     * allows one sender to have multiple remittances. **/
    mapping(bytes32 => RemittanceData) public remittances;

    /**
     * This constructor creates an instance of the Remittance contract.  
     **/
    constructor() public {
        emit ContractCreated(owner);
    }

    modifier onlyWhenPuzzleSolved(string password1, string password2) {
        require(remittances[getKeccak32(password1, password2)].balance != 0, 
            "Passwords not correct or no balance");
        _;
    }
 
    /** Modifier that checks whether the hash is non-empty. Initially
     * when the contract is created, the hash with be empty. Once a 
     * person sends money to the contract, the hash is filled. A hacker might
     * send a small amount of ether in order to overwrite the hashes and
     * thus gain access to the funds. This modifier prevents this kind of
     * attack
     */
    modifier onlyWhenNotSendToAlready(bytes32 hash) {
        require(remittances[hash].balance == 0, "Money already sent associated with hash");
        _;
    }

    /**
     * This function  accepts the keccak32 hash. 
     * The crucial part is that the hash cannot be produred inside the 
     * contract itself, as the passwords on which the keccak32 
     * hashes are based will be stored in transaction 
     * opcodes and can be extracted easily by a hacker. So the hashes should
     * be generates by a tool external to the Remittance contract. Alice
     * will have to generate a hash of the combined strings of the two 
     * passwords. Keccak256 values can be generated here by Alice:
     * https://emn178.github.io/online-tools/keccak_256.html
     * 
     * The sender can set the number of days from ${now} within which he/she 
     * can claim back the funds (without providing the password).
     **/
    function sendMoney(bytes32 hash, uint daysClaim) 
            public payable onlyWhenActive onlyWhenNotSendToAlready(hash) {
        require(daysClaim <= maxDaysClaimBack, "Days claim back too high");
        require(daysClaim > 0, "Days claim back must be greater than 0");
        require(msg.value > 0, "Value sent must be greater than 0");
        emit MoneySent(msg.sender, msg.value);
        remittances[hash].balance = msg.value;
        remittances[hash].deadline = now + (24 * 60 * 60 * daysClaim);
    }

    /**
     * Withdrawal can only be performed if both passwords translate to 
     * hashes that were stored by the sender.
     **/
    function withdraw(string password1, string password2) 
            payable public onlyWhenPuzzleSolved (password1, password2) 
            onlyWhenActive {
        bytes32 hash = getKeccak32(password1, password2);
        uint availableBalance = remittances[hash].balance;
        require(availableBalance != 0, "No balance");
        remittances[hash].balance -= availableBalance;
        emit MoneyWithdrawnBy(msg.sender, availableBalance);
        msg.sender.transfer(availableBalance);
    } 
 
    function claimBack(bytes32 hash) public payable onlyWhenActive {
        require(remittances[hash].balance > 0, "No balance or not original sender");
        require(now <= remittances[hash].deadline, 
            "Deadline reached, funds not claimed back");
        uint availableBalance = remittances[hash].balance;
        remittances[hash].balance = 0;
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
    
    function getKeccak32(string password1, string password2) view public 
            returns (bytes32) {
        return keccak256(abi.encodePacked(msg.sender, password1, password2));        
    }

}