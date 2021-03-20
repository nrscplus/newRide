pragma solidity ^0.5.12;

import './SafeMath.sol';

library NewRideLibrary {
    using SafeMath for uint;
    
    function getReturnAmt(uint _value, uint _dayNum) internal pure returns (uint _retrunAmt) {
        if (_dayNum == 1) {
            _retrunAmt = _value.mul(101) / 100;
        } else if (_dayNum == 7) {
            _retrunAmt = _value.mul(110) / 100;
        } else if (_dayNum == 15) {
            _retrunAmt = _value.mul(130) / 100;
        } else {
            _retrunAmt = _value;
        }
    }
    
    function canGetShare(uint _value, uint _count) internal pure returns (bool) {
        return _value >= _count.mul(100000000);
    }
    
    function getShareAmt(uint _income, uint _count) internal pure returns (uint) {
        if (_count == 1) {
            return _income.mul(30) / 100;
        } else if (_count == 2) {
            return _income.mul(20) / 100;
        } else if (_count == 3) {
            return _income.mul(10) / 100;
        } else if (_count >=4 && _count <=10) {
            return _income.mul(5) / 100;
        } else if (_count >= 11 && _count <= 20) {
            return _income.mul(1) / 100;
        } else {
            return 0;
        }
    }
}
