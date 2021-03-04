pragma solidity ^0.5.12;

import './Base.sol';
import './libraries/SafeMath.sol';
import './libraries/NineRingsLibrary.sol';
import './Transfer.sol';
import './interfaces/ITransfer.sol';
import './interfaces/ITRC20.sol';

contract Collect is Base {
    
    address public admin;
    
    constructor() public {
        admin = msg.sender;
    }
    
    modifier isAdmin() {
        require(msg.sender == admin, "caller not admin");
        _;
    }
    
    function withdraw(address _to, uint _value) external isAdmin returns (bool flag) {
        ITRC20(USDT_ADDR).transfer(_to, _value);
        flag = true;
    }
    
}
