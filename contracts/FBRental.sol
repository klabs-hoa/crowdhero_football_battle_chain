//SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract FBRental {
    
    constructor(address[] memory operators_) {
        _owner       =  msg.sender;
        for(uint i=0; i < operators_.length; i++) {
            address opr = operators_[i];
            require( opr != address(0), "invalid operator");
            _operators[opr] = true;
        }
    }

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;
    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    struct Rental {
        address     host;
        address     renter;
        uint        dateFrom;
        uint        dateTo;
        uint256[]   Nft;
        uint256     budget;
        uint        dateClaim;
    }
    Rental[]                                                                public renting;
    mapping(address => mapping(uint256 => address))                         public renter;
    mapping(address => mapping(uint    => mapping(uint    => uint256)))     public duration;   

    address                                                                 public cryptoContract;
    address                                                                 public NftContract;

    mapping(address =>  bool)                           private _operators;
    address                                             private _owner;
    bool                                                private _ownerLock = true;

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

    function opSetDurationAmount(address host_,uint numberNft ,uint duration_, uint256 min_) public chkOperator {
        duration[host_][numberNft][duration_] = min_;
    }

    function opSetNFTContract(address nftContract_) public chkOperator {
        NftContract = nftContract_;
    }
    function opSetCrypto(address crypto_) public chkOperator {
        cryptoContract = crypto_;
    }

    function opUpdateHost(uint256 rentId_, address host_) public chkOperator {
        require(ERC721(NftContract).ownerOf(renting[rentId_].Nft[0]) == host_,"invalid host");
        renting[rentId_].host = host_;

    }
    function rentNFT(address host_, uint duration_, uint256[] memory nfts_, uint256 amount_) external payable returns(uint256) {
        require(duration[host_][nfts_.length][duration_] > 0,"invalid");
        require(amount_  >= duration[host_][nfts_.length][duration_],  "invalid amount");
    
        _cryptoTransferFrom(msg.sender, address(this), cryptoContract, amount_);
       
        for(uint256 vI = 0; vI < nfts_.length; vI++) {
            require(ERC721(NftContract).ownerOf(nfts_[vI]) == host_,"invalid owner");
            _owners[nfts_[vI]] =   msg.sender;
        }
        _balances[msg.sender]   += nfts_.length;

        Rental memory vRental;
        vRental.host        = host_;
        vRental.renter      = msg.sender;
        vRental.dateFrom    = block.timestamp;
        vRental.dateTo      = block.timestamp + duration_;
        vRental.Nft         = nfts_;
        vRental.budget      = amount_;
        renting.push(vRental);

        renter[msg.sender][renting.length-1]    = host_;

        return renting.length-1;
    }

    function claimNFT(uint256 rentId_) external {
        require( renting[rentId_].dateTo < block.timestamp,"invalid dateTo");
        require( renting[rentId_].dateClaim == 0,"claimed");
        
        uint256[] memory vIndex = renting[rentId_].Nft;
        for(uint256 vI = 0; vI < vIndex.length; vI++) {
            delete _owners[vIndex[vI]];
        }
        _balances[renting[rentId_].renter] -= vIndex.length;

        renting[rentId_].dateClaim  = block.timestamp;
        _cryptoTransfer(renting[rentId_].host, cryptoContract, renting[rentId_].budget);
        delete renter[renting[rentId_].renter][rentId_];
    }

    function balanceOf(address renter_) public view returns (uint256) {
        require(renter_ != address(0), "ERC721: balance query for the zero address");
        return _balances[renter_];
    }

    function RenterOf(uint256[] memory tokenIds_) public view returns (address vOwner) {
        vOwner  =   _owners[tokenIds_[0]];
        for(uint256 vI = 1; vI < tokenIds_.length; vI++) {
            if(vOwner != _owners[tokenIds_[vI]])
                return address(0);
        }
        return vOwner;
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
    function setOperator(address opr_, bool val_) public {
        _operators[opr_] = val_;
    }
}
