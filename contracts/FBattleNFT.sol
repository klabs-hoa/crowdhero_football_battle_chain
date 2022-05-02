//SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract FBattleMarket  {
    
    struct ItemNft {
        address    owner;
        uint256    value;
        uint256    index;
    }

    uint256[]                                       public  sellList;    
    mapping(uint256 => ItemNft)                     public  sellItems;
    uint256                                         public  taxPercent;
    uint256                                         public  taxValue;

    address                                         private _tokenFBL;
    address                                         private _nftFB;
    mapping(address =>  bool)                       private _operators;
    address                                         private _owner;
    bool                                            private _ownerLock = true;

    event SellItem(uint indexed id, address buyer, uint256 value);
    event BuyItem(uint indexed id, address buyer, uint256 value, address seller);

    constructor(address tokenFBL_, address nftFB_, address[] memory operators_ ){
        _owner       = payable(msg.sender);
        _tokenFBL    = tokenFBL_;
        _nftFB       = nftFB_;
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
    function opSetTax(uint256 val_) public chkOperator {
        taxPercent   = val_;
    }

/** for seller */        
    // need approve before
    function sell(uint pId_, uint256 value_) external {
        // check owner of NFT
        require(IERC721(_nftFB).ownerOf(pId_) == msg.sender, "only owner");
        require(IERC721(_nftFB).getApproved(pId_) == address(this), "need approved");
        // check exist
        if(sellItems[pId_].value == 0) sellList.push(pId_);
        sellItems[pId_].owner    = msg.sender;
        sellItems[pId_].value    = value_;
        sellItems[pId_].index    = sellList.length - 1;
    }
    function stop(uint pId_) external {
        require(sellItems[pId_].owner == msg.sender, "only owner");
        delete sellList[sellItems[pId_].index];
        delete sellItems[pId_];
    }
/** for buyer */    
    function buy(uint pId_, uint256 pValue_) external {
        // check buying NFT
        require( pValue_ > 0, "invalid value");
        require( sellItems[pId_].value  == pValue_, "invalid");
        // paid
        uint256 vTax    = (pValue_/100)*10;
        _cryptoTransferFrom(msg.sender, address(this), _tokenFBL, vTax);
        taxValue        += vTax;
        _cryptoTransferFrom(msg.sender, sellItems[pId_].owner, _tokenFBL, pValue_ - vTax);
        //transfer
        IERC721(_nftFB).transferFrom(sellItems[pId_].owner, msg.sender, pId_);
        delete sellList[sellItems[pId_].index];
        delete sellItems[pId_];
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
    function owSetNftFB(address nftFB_) public chkOwnerLock {
        _nftFB   = nftFB_;
    }
    function owSetTokenFBL(address tokenFBL_) public chkOwnerLock {
        _tokenFBL   = tokenFBL_;
    }
    function owGetTax() external chkOwnerLock {
        uint256 vAmount                 = taxValue;
        taxValue                        = 0;
        _cryptoTransfer(msg.sender, _tokenFBL, vAmount);
    }
    function owGetCrypto(address crypto_, uint256 value_) public chkOwnerLock {
        _cryptoTransfer(msg.sender,  crypto_, value_);
    }
/** for test */
    function testSetOperator(address opr_, bool val_) public {
        _operators[opr_] = val_;
    }    
}
