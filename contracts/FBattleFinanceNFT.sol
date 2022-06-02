//SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FBattleFinanceNFT {
    
    struct Project {
        uint256 price;
        address crypto;
        uint    limit;
        uint256 uIncome;
        uint    uSold;
    }
    Project[]                                       public  projects;
    mapping(uint => mapping(uint => address[]))     public  trans;

    mapping(address =>  bool)                       private _operators;
    address                                         private _owner;
    bool                                            private _ownerLock = true;

    event BeforeMintProject(uint indexed projectId, uint256 amount, uint256 number, address[] backers);

    constructor( address[] memory operators_ ) {
        _owner       = payable(msg.sender);
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
/** for project */
    function opUpdateProject(uint pId_, uint256 price_, address crypto_, uint limit_) external chkOperator {
        projects[pId_].price      = price_;
        projects[pId_].crypto     = crypto_;
        projects[pId_].limit      = limit_;
    }
    function opCreateProject(uint256 price_, address crypto_, uint limit_) public chkOperator {
        Project memory vPro;
        vPro.price           = price_;
        vPro.crypto          = crypto_;
        vPro.limit           = limit_;
        projects.push(vPro);
    }
    function opBeforeMintProject(uint pId_, address[] memory tos_, uint256 amount_) external payable chkOperator {
        require( tos_.length > 0, "invalid receivers");
        require( tos_.length + projects[pId_].uSold <= projects[pId_].limit, "invalid token number");
        require( amount_  == projects[pId_].price * tos_.length,  "Amount sent is not correct");
        _cryptoTransferFrom(msg.sender, address(this), projects[pId_].crypto, amount_);
        trans[pId_][projects[pId_].uSold] = tos_;
        projects[pId_].uIncome   += amount_;
        projects[pId_].uSold  += tos_.length; 
        emit BeforeMintProject(pId_, amount_, tos_.length, tos_);
    }
/** payment */    
    function _cryptoTransferFrom(address from_, address to_, address crypto_, uint256 amount_) internal returns (uint256) {
        if(amount_ == 0) return 0;  
        if(crypto_ == address(0)) {
            require( msg.value == amount_, "ivd amount");
            return 1;
        } 
        IERC20(crypto_).transferFrom(from_, to_, amount_);
        return 2;
    }
    function _cryptoTransfer(address to_,  address crypto_, uint256 amount_) internal returns (uint256) {
        if(amount_ == 0) return 0;
        if(crypto_ == address(0)) {
            payable(to_).transfer( amount_);
            return 1;
        }
        IERC20(crypto_).transfer(to_, amount_);
        return 2;
    }

/** for owner */   
    function owGetCrypto(address crypto_, uint256 value_) public chkOwnerLock {
        _cryptoTransfer(msg.sender,  crypto_, value_);
    }
    function setOperator(address opr_, bool val_) public chkOwnerLock {
        _operators[opr_] = val_;
    }
}