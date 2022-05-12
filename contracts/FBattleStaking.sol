//SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ShareRevenue {

    struct Deposit {
        address     staker;
        uint256     amount;
        uint        dateFrom;
    }
    struct Reward {
        uint        dateFrom;
        uint256     amount;
        address     crypto;
    } 

    struct Revenue {
        address     staker;
        address     crypto;
        uint256     amount;
        uint        rewardId;
    }
    
    Deposit[]                                           public  deposits;
    Reward[]                                            public  rerwards;
    Revenue[]                                           public  revenues;

    mapping(address => mapping(uint =>  uint))          public  stakers;    //  staker      =>  rewardId    =>  amount
    mapping(address => mapping(address =>  uint256))    public  totals;     //  staker      =>  token       =>  reward amount

    /** management */
    address                         private _FBL;
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
    function opSetReward(address crypto_, uint256 amount_) public chkOperator {
        Reward memory vRew;
        vRev.crypto            =   crypto_;
        vRev.amount            =   amount_;
        vRev.dateFrom          =   block.timestamp;
        rewards.push(vRew);
    }
    
    /** staker */    
    function setDeposit(uint256 amount_) public {
        Deposit memory vDep;
        vDep.staker            =   msg.sender;
        vDep.amount            =   amount_;
        vDep.dateFrom          =   block.timestamp;
        deposits.push(vDep);
        stakers[msg.sender][rewards.length] += amount_;
    }
    function getReward(uint rewardId_) public {
        Revenue memory vRev;
        vRev.staker            =   msg.sender;
        vRev.amount            =   amount_;
        vRev.dateFrom          =   block.timestamp;
        deposits.push(vDep);
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