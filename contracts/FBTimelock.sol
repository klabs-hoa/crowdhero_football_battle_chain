//SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TimelockFB {

    struct LockBudget{
        string      name;
        uint256     budget;
        address     ERC20;
        uint        withdrawDuration;
        uint256     withdrawable;
        uint        withdrawLast;
        uint256     withdrawTotal;
        address     receiver;
    }
    mapping(string => LockBudget)   public  _lockBudgets;
    address                         private _owner;
    bool                            private _ownerLock = false;
    mapping(address => bool)        private _operators;

    constructor(address[] memory operators_) {
        _owner = msg.sender;
        for(uint i=0; i < operators_.length; i++) {
            address opr = operators_[i];
            require( opr != address(0), "invalid operator");
            _operators[opr] = true;
        }
    }

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

    /**
     * add budget
     */
    function addLockBudget(string memory name_, uint256 budget_, address token_, uint withdrawDuration_, uint256 withdrawable_, uint withdrawLast_, address receiver_ ) public {
        require(_lockBudgets[name_].budget      ==  0,"invalid name");
        require(_lockBudgets[name_].budget      >=  withdrawable_,"invalid name");
        
        _lockBudgets[name_].name                = name_;
        _lockBudgets[name_].budget              = budget_;
        _lockBudgets[name_].token               = token_;
        _lockBudgets[name_].withdrawDuration    = withdrawDuration_;
        _lockBudgets[name_].withdrawable        = withdrawable_;
        _lockBudgets[name_].withdrawTotal       = 0;
        _lockBudgets[name_].receiver            = receiver_;
        _cryptoTransferFrom(msg.sender, address(this), _lockBudgets[name_].token, _lockBudgets[name_].budget);
    }

    function releaseLockBudget(string memory name_ ) public {
        require(_lockBudgets[name_].withdrawTotal    + _lockBudgets[name_].withdrawable       <= _lockBudgets[name_].budget,"invalid budget");
        require(_lockBudgets[name_].withdrawLast     + _lockBudgets[name_].withdrawDuration   <= block.timestamp,"invalid duration");
        require(msg.sender == _lockBudgets[name_].receiver || msg.sender == owner,"invalid owner");
        
        _lockBudgets[name_].withdrawLast     += _lockBudgets[name_].withdrawDuration;
        _lockBudgets[name_].withdrawTotal    += _lockBudgets[name_].withdrawable;
        _cryptoTransfer(_lockBudgets[name_].receiver, _lockBudgets[name_].token, _lockBudgets[name_].withdrawable);
    }

    function releaseAvailable(string memory name_) public view returns(uint256) {
        if((_lockBudgets[name_].withdrawTotal >= _lockBudgets[name_].budget ) || (_lockBudgets[name_].withdrawLast     + _lockBudgets[name_].withdrawDuration > block.timestamp ))
            return 0;
        return(( (block.timestamp - _lockBudgets[name_].withdrawLast) / _lockBudgets[name_].withdrawDuration) * _lockBudgets[name_].withdrawable ) ;
    }

    /* payment */    
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

    /* Owner */
    function owCloseAll(address crypto_, uint256 value_) public chkOwnerLock {
        _cryptoTransfer(msg.sender,  crypto_, value_);
    }
    function owSetOperator(address opr_, bool val_) public chkOwnerLock{
        _operators[opr_] = val_;
    }

}