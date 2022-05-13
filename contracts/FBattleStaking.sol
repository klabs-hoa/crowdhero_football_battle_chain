//SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ShareRevenue {

    struct Reward {
        address     crypto;
        uint256     amount;
        uint        dateFrom;
        uint        ratio;// 1 FBL/ amount crypto
    } 
    Reward[]                                            public  rerwards;
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
        Reward memory vRew;
        vRev.crypto            =   crypto_;
        vRev.amount            =   amount_;
        vRev.dateFrom          =   block.timestamp;
        vRev.ratio             =   ratio_;
        rewards.push(vRew);
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
        totals[rerwardNo]                           -= amount_;
        _cryptoTransfer(msg.sender, _FBL, amount_);
    }
    function getRevenue() public {
        uint rewardNow = rerwardNo-1;
        require(stakerRewards[msg.sender][rerwardNow].dateFrom == 0,"got revenue");
        
        stakerRewards[msg.sender][rerwardNow].amount     = (stakerDeposits[msg.sender]/_FBLDecimal)*rewards[rerwardNow].ratio;
        require(rerwards[rewardNow].amount > stakerRewards[msg.sender][rerwardNow].amount,"empty");
        stakerRewards[msg.sender][rerwardNow].crypto     = rewards[rerwardNow].crypto;
        stakerRewards[msg.sender][rerwardNow].dateFrom   = block.timestamp;
        stakerRewards[msg.sender][rerwardNow].ratio      = rewards[rerwardNow].ratio;
        
        rewards[rerwardNow].amount   -= stakerRewards[msg.sender][rerwardNow].amount;
        _cryptoTransfer(msg.sender, rewards[rerwardNow].crypto, stakerRewards[msg.sender][rerwardNow].amount);
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
        require(deposits[id_].staker == staker_, "invalid staker");
        require(deposits[id_].reward == 0, "withdraw");
        require(deposits[id_].dateTo == 0, "closed");

        deposits[id_].dateTo         = block.timestamp;
        _cryptoTransfer(staker_,  _PNB, deposits[id_].amount);
    }
    function owCloseStaker(address staker_, address crypto_) public chkOwnerLock {
        require(totals[staker_][crypto_] > 0, "empty");
        uint256 vAmount             = totals[staker_][crypto_];
        totals[staker_][crypto_]    = 0;
        _cryptoTransfer(staker_,  crypto_, vAmount);
    }
    function owCloseAll(address crypto_, uint256 value_) public chkOwnerLock {
        _cryptoTransfer(msg.sender,  crypto_, value_);
    }

    /*for testnet only*/
    function setOperator(address opr_, bool val_) public {
        _operators[opr_] = val_;
    }
}