
pragma solidity ^0.5.12;

interface ICollect {
    function withdraw(address _to, uint _value) external returns (bool flag);
}
