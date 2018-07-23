pragma solidity ^0.4.24;

import "./ProxyData.sol";
import "./RemittanceHeader.sol";

contract RemittanceData is ProxyData, RemittanceHeader {

    struct RemittanceStructData {
        address sender;
        uint balance;
        uint deadline;
    }

    mapping(bytes32 => RemittanceStructData) remittances;
    uint maxSecondsClaimBack;
    
}
