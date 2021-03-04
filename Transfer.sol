pragma solidity ^0.5.12;

import './Base.sol';
import './interfaces/ITRC20.sol';

contract Transfer is Base {
    
    address public admin;
    
    constructor() public {
        admin = msg.sender;
    }
    
    modifier isAdmin() {
        require(msg.sender == admin, "caller not admin");
        _;
    }
    
    function transferUser(address _to, uint _value) external isAdmin returns (bool flag) {
        ITRC20(USDT_ADDR).transfer(_to, _value);
        flag = true;
    }
}
