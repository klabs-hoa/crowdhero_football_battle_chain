//SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FBL is ERC20 {

    mapping(address =>  bool)                       private _operators;
    address                                         private _owner;
    bool                                            private _ownerLock = true;
    address                                         private stock;

    constructor(address stock_, address[] memory operators_) ERC20 ("FootballBattle Game", "FBT") {   
        _owner          = payable(msg.sender);
        stock           = stock_; 
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
    /** for operator */
    function opSetOwnerLock(bool val_) public chkOperator {
        _ownerLock   = val_;
    }
    function mint(uint256 amount_) public chkOperator {
        _mint(stock, amount_);
    }

    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }
    /** for owner */
    function owSetOperator(address opr_, bool val_) public chkOwnerLock {
        _operators[opr_] = val_;
    }
    function owSetStockAdd(address stock_) public chkOwnerLock {
        stock = stock_;
    }
}
