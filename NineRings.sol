pragma solidity ^0.5.12;

import './Base.sol';
import './libraries/NineRingsLibrary.sol';
import './Transfer.sol';
import './Collect.sol';
import './interfaces/ITransfer.sol';
import './interfaces/ICollect.sol';
import './interfaces/ITRC20.sol';

contract NineRings is Base {
    
    address public owner;
    address public callAddr;
    address private collectAddr;
    
    constructor(address _callAddr, address _owner) public {
        owner = _owner;
        callAddr = _callAddr;
        Collect c = new Collect();
        collectAddr = address(c);
    }
    
    // 用户信息
    struct Player {
        uint id;                            // 用户id
        address addr;                       // 用户地址
        uint referrerId;                    // 推荐人(上一级)id：0表示没有推荐人(上一级)
        uint[] oneFriends;                  // 1代好友列表，存放的是id
        uint[] orderIds;                    // 所有订单id
        uint[] awardIds;                    // 所有奖励id
        uint allCirculationAmt;             // 用户的总流通金额
        uint allReturnAmt;                  // 用户的总返回金额
        uint shareRewardsAmt;               // 用户的分享奖励金额
        uint createRingAmt;                 // 用户的创环奖励金额
        address transferAddr;               // 用户交易地址
    }
    uint public playerCount;                // 用户id，自增长
    mapping(address => uint) public playerAddrMap;                      // 用户地址 => 用户id
    mapping(uint => Player) public playerMap;                           // 用户id => 用户信息
    
    struct Order {
        uint id;                            // 订单id
        uint playerId;                      // 用户id
        uint circulationAmt;                // 用户流通金额
        uint circulationDays;               // 用户流通天数
        uint returnAmt;                     // 用户返回金额
        uint status;                        // 订单状态(如果流通天数未过，状态为0(未完成)；已过，状态为1(已完成))
        uint time;
        uint[] profitIds;            
        uint[] profitAmts;
    }
    uint public orderCount;                 // 订单id，自增长
    mapping(uint => Order) public orderMap;   // 订单id => 订单信息
    
    uint public circulationAmt;         // 所有用户的总流通金额
    uint public createRingAmt;          // 创环奖池金额
    
    event Buy(address indexed _msgSender, uint _value, uint _dayNum, address _referrerAddr);
    
    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }
    
    function getOneFriends() external view returns (uint[] memory) {
        return getOneFriendsById(playerAddrMap[msg.sender]);
    }
    
    function getOneFriendsById(uint _id) public view returns (uint[] memory) {
        return playerMap[_id].oneFriends;
    }
    
    function getOrderIds() external view returns (uint[] memory) {
        return getOrderIdsById(playerAddrMap[msg.sender]);
    }
    
    function getOrderIdsById(uint _id) public view returns (uint[] memory) {
        return playerMap[_id].orderIds;
    }
    
    function getProfitIds(uint _orderId) external view returns (uint[] memory) {
        return orderMap[_orderId].profitIds;
    }
    
    function getProfitAmts(uint _orderId) external view returns (uint[] memory) {
        return orderMap[_orderId].profitAmts;
    }
    
    function getBalance() public view returns (uint) {
        return ITRC20(USDT_ADDR).balanceOf(collectAddr);
    }
    
    function buy(uint _value, uint _dayNum, address _referrerAddr) lock external returns(bool flag) {
        require(_dayNum == 1 || _dayNum == 7 || _dayNum == 15, "_dayNum is error");
        uint _id = _register(msg.sender);
        address transferAddr = playerMap[_id].transferAddr;
        require(ITRC20(USDT_ADDR).transferFrom(msg.sender, address(this), _value), "transferFrom USDT fail");
        ITRC20(USDT_ADDR).transfer(transferAddr, _value);
        require(ITransfer(transferAddr).transferUser(collectAddr, _value), "transferUser USDT fail");
        
        if (msg.sender != _referrerAddr) {
            _saveReferrerInfo(_id, _referrerAddr);  // 保存推荐人信息
        }
        // 保存订单信息
        uint _orderId = _saveOrder(_id, _value, _dayNum);
        playerMap[_id].orderIds.push(_orderId);
        playerMap[_id].allCirculationAmt = playerMap[_id].allCirculationAmt.add(_value);
        
        circulationAmt = circulationAmt.add(_value);
        
        _calcuSuperUser2(playerMap[_id].referrerId, orderMap[_orderId].returnAmt.sub(orderMap[_orderId].circulationAmt), 0, _orderId);
        
        flag = true;
        emit Buy(msg.sender, _value, _dayNum, _referrerAddr);
    }
    
    // 保存订单信息
    function _saveOrder(uint _playerId, uint _value, uint _dayNum) internal returns(uint) {
        orderCount ++;
        uint _orderId = orderCount;
        orderMap[_orderId].id = _orderId;
        orderMap[_orderId].playerId = _playerId;
        orderMap[_orderId].circulationAmt = _value;
        orderMap[_orderId].circulationDays = _dayNum;
        orderMap[_orderId].returnAmt = NineRingsLibrary.getReturnAmt(_value, _dayNum);
        orderMap[_orderId].time = block.timestamp;
        return _orderId;
    }
    
    // 保存推荐人信息
    function _saveReferrerInfo(uint _id, address _referrerAddr) internal {
        uint _referrerId = playerAddrMap[_referrerAddr];
        // playerMap[_id].allCirculationAmt == 0 这个条件是为了防止形成邀请关系的闭环
        if (_referrerId > 0 && playerMap[_id].referrerId == 0 && playerMap[_id].allCirculationAmt == 0) {
            playerMap[_id].referrerId = _referrerId;
            playerMap[_referrerId].oneFriends.push(_id);
        }
    }
    
    // 注册
    function _register(address _sender) internal returns (uint _id) {
        _id = playerAddrMap[_sender];
        if (_id == 0) {   // 未注册
            playerCount++;
            _id = playerCount;
            playerAddrMap[_sender] = _id;
            playerMap[_id].id = _id;
            playerMap[_id].addr = _sender;
            playerMap[_id].transferAddr = _createTransferContract();
        }
    }
    
    // 到期之后的流通返回
    function returnAmt(uint _orderId) external canCallAddr {
        if (_orderId > 0 && orderMap[_orderId].status == 0 && orderMap[_orderId].circulationAmt > 0) {
            uint _playerId = orderMap[_orderId].playerId;
            if (_playerId > 0 && playerMap[_playerId].allCirculationAmt > 0) {
                uint _circulationDays = orderMap[_orderId].circulationDays;
                uint _orderTime = orderMap[_orderId].time;
                // TODO
                uint _expireTime = _orderTime.add(_circulationDays.mul(24*60*60));
                // uint _expireTime = _orderTime.add(_circulationDays.mul(1*60));
                uint _nowTime = block.timestamp;
                if (_nowTime > _expireTime) {
                    // 已到期，返回金额给用户
                    orderMap[_orderId].status = 1;
                    address _userAddr = playerMap[_playerId].addr;
                    uint _returnAmt = orderMap[_orderId].returnAmt;
                    require(ICollect(collectAddr).withdraw(_userAddr, _returnAmt), "Transfer return to user USDT fail");
                    playerMap[_playerId].allReturnAmt = playerMap[_playerId].allReturnAmt.add(_returnAmt);
                    
                    // 计算上级用户的奖励并转账
                    _calcuSuperUser(playerMap[_playerId].referrerId, 
                        orderMap[_orderId].returnAmt.sub(orderMap[_orderId].circulationAmt), 0, _orderId);
                }
            }
        }
    }
    
    function _calcuSuperUser(uint _referrerId, uint _income, uint _count, uint _orderId) private {
        if (_referrerId == 0) {
            return;
        }
        _count++;
        if (_count > 20) {
            return;
        }
        if (NineRingsLibrary.canGetShare(playerMap[_referrerId].allCirculationAmt, _count)) {
            uint _share = NineRingsLibrary.getShareAmt(_income, _count);
            require(ICollect(collectAddr).withdraw(playerMap[_referrerId].addr, _share), 
                "Transfer share to user USDT fail");
            playerMap[_referrerId].shareRewardsAmt = playerMap[_referrerId].shareRewardsAmt.add(_share);
        }
        _calcuSuperUser(playerMap[_referrerId].referrerId, _income, _count, _orderId);
    }
    
    function _calcuSuperUser2(uint _referrerId, uint _income, uint _count, uint _orderId) private {
        if (_referrerId == 0) {
            return;
        }
        if (orderMap[_orderId].profitIds.length == 0) {
            orderMap[_orderId].profitIds = new uint[](20);
        }
        if (orderMap[_orderId].profitAmts.length == 0) {
            orderMap[_orderId].profitAmts = new uint[](20);
        }
        _count++;
        if (_count > 20) {
            return;
        }
        if (NineRingsLibrary.canGetShare(playerMap[_referrerId].allCirculationAmt, _count)) {
            uint _share = NineRingsLibrary.getShareAmt(_income, _count);
            _saveAward(_referrerId, _orderId, _share, _count);
        }
        _calcuSuperUser2(playerMap[_referrerId].referrerId, _income, _count, _orderId);
    }
    
    function _saveAward(uint _playerId, uint _orderId, uint _share, uint _count) private {
        orderMap[_orderId].profitIds[_count - 1] = _playerId;
        orderMap[_orderId].profitAmts[_count - 1] = _share;
    }
    
    function _createTransferContract() private returns (address transferAddr) {
        Transfer t = new Transfer();
        transferAddr = address(t);
    }
    
    
    modifier canCallAddr() {
        require(msg.sender == callAddr, "is not callAddr");
        _;
    }
    
    modifier isOwner() {
        require(msg.sender == owner, "is not owner");
        _;
    }
    
    function setOwner(address _addr) external isOwner {
        owner = _addr;
    }
    
    function setCallAddr(address _addr) external isOwner {
        callAddr = _addr;
    }
    
}


