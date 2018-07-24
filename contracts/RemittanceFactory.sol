pragma solidity ^0.4.24;

import "./Remittance.sol";
import "./RemittanceProxy.sol";

contract RemittanceFactory {
    
    Remittance private masterCopy;
    
    constructor(Remittance _masterCopy) public {
        masterCopy = _masterCopy;
    }
    
    function createRemittance(uint256 maxSecondsClaimBack)
        public
        returns (Remittance) {
        return Remittance(new RemittanceProxy(masterCopy, maxSecondsClaimBack));
    }
    
}