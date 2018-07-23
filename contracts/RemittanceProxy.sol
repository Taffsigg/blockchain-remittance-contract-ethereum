pragma solidity ^0.4.24;

import "./Proxy.sol";
import "./RemittanceData.sol";

contract RemittanceProxy is Proxy, RemittanceData {

    constructor(address proxied, uint256 _maxSecondsClaimBack) 
        public Proxy(proxied){

        maxSecondsClaimBack = _maxSecondsClaimBack;
        
    }

}

