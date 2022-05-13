//SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FBStaking {

    struct Reward {
        address     crypto;
        uint256     amount;
        uint        dateFrom;
        uint        ratio;// 1 FBL/ amount crypto
    } 
    Reward[]                                            public  rewards;
    uint                                                public  rewardNo;
    uint256[]                                           public  totals;     //  rewardid    =>  total deposit

    mapping(address => uint)                            public  stakerDeposits;
    mapping(address => mapping(uint => Reward))         public  stakerRewards;    //  staker      =>  rewardId    =>  amount,crypto

    /** management */
    address                         private _FBL;
    uint                            private _FBLDecimal;
    address                         private _owner;
    bool                            private _ownerLock = true;
    mapping(address => bool)        private _operators;
    

    modifier chkOperator() {
        require(_operators[msg.sender], "only for operator");
        _;
    }
    modifier chkOwnerLock() {
        require( _owner     ==  msg.sender, "only for owner");
        require( _ownerLock ==  false, "lock not open");
        _;
    }
    function opSetOwnerLock(bool val_) public chkOperator {
        _ownerLock   = val_;
    }

    function getDayNum(uint dateFrom_, uint dateTo_) pure internal returns(uint vDayNum) {
        require(dateFrom_ < dateTo_, "invalid date");
        vDayNum  = uint((dateTo_ - dateFrom_)/86400);
    }

    /** operator */    
    function opSetReward(address crypto_, uint256 amount_, uint ratio_) public chkOperator {
        _cryptoTransferFrom(msg.sender, address(this), crypto_, amount_);
        Reward memory vRev;
        vRev.crypto            =   crypto_;
        vRev.amount            =   amount_;
        vRev.dateFrom          =   block.timestamp;
        vRev.ratio             =   ratio_;
        rewards.push(vRev);
        rewardNo++;
    }

    /** staker */    
    function setDeposit(uint256 amount_) public {
        _cryptoTransferFrom(msg.sender, address(this), _FBL, amount_);
        stakerDeposits[msg.sender]                  += amount_;
        totals[rewardNo]                            += amount_;
    }
    function getDeposit(uint256 amount_) public {
        require(stakerDeposits[msg.sender] > amount_,"invalid amount");
        stakerDeposits[msg.sender]                  -= amount_;
        totals[rewardNo]                            -= amount_;
        _cryptoTransfer(msg.sender, _FBL, amount_);
    }
    function getRevenue() public {
        uint rewardNow = rewardNo-1;
        require(stakerRewards[msg.sender][rewardNow].dateFrom == 0,"got revenue");
        
        stakerRewards[msg.sender][rewardNow].amount     = (stakerDeposits[msg.sender]/_FBLDecimal)*rewards[rewardNow].ratio;
        require(rewards[rewardNow].amount > stakerRewards[msg.sender][rewardNow].amount,"empty");
        stakerRewards[msg.sender][rewardNow].crypto     = rewards[rewardNow].crypto;
        stakerRewards[msg.sender][rewardNow].dateFrom   = block.timestamp;
        stakerRewards[msg.sender][rewardNow].ratio      = rewards[rewardNow].ratio;
        
        rewards[rewardNow].amount   -= stakerRewards[msg.sender][rewardNow].amount;
        _cryptoTransfer(msg.sender, rewards[rewardNow].crypto, stakerRewards[msg.sender][rewardNow].amount);
    }
 
    /** payment */    
    function _cryptoTransferFrom(address from_, address to_, address crypto_, uint256 amount_) internal returns (uint256) {
        if(amount_ == 0) return 0;  
        // use native
        if(crypto_ == address(0)) {
            require( msg.value == amount_, "invalid amount");
            return 1;
        } 
        // use token    
        IERC20(crypto_).transferFrom(from_, to_, amount_);
        return 2;
    }
    function _cryptoTransfer(address to_,  address crypto_, uint256 amount_) internal returns (uint256) {
        if(amount_ == 0) return 0;
        // use native
        if(crypto_ == address(0)) {
            payable(to_).transfer( amount_);
            return 1;
        }
        // use token
        IERC20(crypto_).transfer(to_, amount_);
        return 2;
    }

    /** Owner */
    function owCloseDeposit(uint id_, address staker_) public chkOwnerLock {        
        require(stakerDeposits[staker_] == id_, "invalid staker");
        require(stakerDeposits[staker_] >  0, "withdrawed");
        stakerDeposits[staker_]         =  0;
        _cryptoTransfer(staker_,  _FBL, stakerDeposits[staker_]);
    }
    function owCloseAll(address crypto_, uint256 value_) public chkOwnerLock {
        _cryptoTransfer(msg.sender,  crypto_, value_);
    }

    /*for testnet only*/
    function setOperator(address opr_, bool val_) public {
        _operators[opr_] = val_;
    }
}