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

    mapping(bytes32 => uint) public balances;
    mapping(bytes32 => uint) public deadlines;
    mapping(address => bytes32) public senders;

    /**
     * This constructor creates an instance of the Remittance contract.  
     **/
    constructor() public {
        emit ContractCreated(owner);
    }

    modifier onlyWhenPuzzleSolved(string password1, string password2) {
        require(getKeccak32(password1, password2) != 0, "Passwords not correct");
        _;
    }
 
    /** Modifier that checks whether the hashes are non-empty. Initially
     *  when the contract is created, the hashes with be empty. Once a 
     *  person sends money to the contract, hashes are filled. A hacker might
     *  send a small amount of ether in order to overwrite the hashes and
     *  thus gain access to the funds.
     */
    modifier onlyWhenNotSendToAlready(bytes32 hash) {
        require(balances[hash] == 0, "Money already sent associated with hash");
        _;
    }

    /**
     * This function  accepts the keccak32 hash. 
     * The crucial part is that the hashes cannot be produred inside the 
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
        balances[hash] = msg.value;
        deadlines[hash] = now + (24 * 60 * 60 * daysClaim);
        /** Store the combination of sender and hash to be able to claim back
         * later **/
        senders[msg.sender] = hash;
    }

    /**
     * Withdrawal that takes the funds from the balance identified by the hash
     * provided by the sender.
     **/
    function withdraw(string password1, string password2) 
            payable public onlyWhenPuzzleSolved (password1, password2) 
            onlyWhenActive {
        uint availableBalance = balances[getKeccak32(password1, password2)];
        require(availableBalance != 0, "No balance");
        // Decrease the balance of the sender (identified with the hash)
        balances[getKeccak32(password1, password2)] -= availableBalance;
        emit MoneyWithdrawnBy(msg.sender, availableBalance);
        msg.sender.transfer(availableBalance);
    } 
 
    function claimBack(bytes32 hash) public payable onlyWhenActive {
        require(senders[msg.sender] == hash, "Not the original sender");
        require(balances[hash] != 0, "No balance");
        require(now <= deadlines[hash], "Deadline reached, funds not claimed back");
        emit MoneyClaimedBack(msg.sender);
        msg.sender.transfer(balances[hash]);
    }
    
    /**
     * Fallback function which shouldn't be used to send money to the contract,
     * so don't make it payable
     **/
    function() public {
        
        revert("Not implemented");
        
    }
    
    function getKeccak32(string password1, string password2) pure private 
            returns (bytes32) {
        return keccak256(abi.encodePacked(password1, password2));        
    }
    
}