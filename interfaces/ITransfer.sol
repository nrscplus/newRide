pragma solidity ^0.5.12;

interface ITransfer {
    function transferUser(address _to, uint _value) external returns (bool flag);
}
