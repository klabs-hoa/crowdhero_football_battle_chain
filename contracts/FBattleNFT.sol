//SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FBPlayer721 is ERC721 {
    using Strings for uint256;
    
    struct Project {
        uint256 price;
        address crypto;
        string  URI;
        uint    limit;
        uint256 uIncome;
        uint    uCurrent;
    }
    struct Info {
        uint    proId;
        uint    proIndex;
        uint256 ownedposition;
    }

    uint256                                         public  tokenIdCurrent;
    Project[]                                       public  projects;
    Info[]                                          public  infos;          
    mapping(uint    =>  string)                     private URLs;
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    mapping(address =>  bool)                       private _operators;
    address                                         private _owner;
    bool                                            private _ownerLock = true;

    event CreateProject(uint indexed fundId, uint indexed projectId, string URI);
    event MintProject(uint indexed projectId, uint indexed number, uint256 current, address backer);

    constructor( address[] memory operators_ ) ERC721 ("FootballBattle Player", "FBP") {
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
    function opUpdateTokenUrl(uint256 tokenId_, string memory url_) public chkOperator { 
        URLs[tokenId_]    = url_;
    }
    function opUpdateProject(uint pId_, uint256 price_, uint256 limit_, string memory URI_) external chkOperator {
        projects[pId_].price      = price_;
        projects[pId_].URI        = URI_;
        projects[pId_].limit      = limit_;
    }
    function ownerTokens(address own_) external view returns(uint[][] memory) {
        uint256  vOwnerNum      = balanceOf(own_); 
        require(vOwnerNum > 0, "none NFT");
        uint[][] memory vTkns   = new uint[][](vOwnerNum);
        uint256 vTknId;
        for(uint256 vI = 1; vI <= vOwnerNum; vI++) {
            vTkns[vI-1]      = new uint[](2);
            vTknId           = _ownedTokens[own_][vI];
            vTkns[vI-1][0]   = vTknId;
            vTkns[vI-1][1]   = infos[vTknId].proId;
        }
        return vTkns;
    }
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);
        
        if (from != address(0)) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if(to != address(0)) {
            _addTokenToOwnerEnumeration(to, tokenId);
        } 
    }
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = balanceOf(to)+1;
        _ownedTokens[to][length] = tokenId;
        infos[tokenId].ownedposition = length;
    }
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        uint256 lastTokenIndex = balanceOf(from);
        uint256 ownedposition = infos[tokenId].ownedposition;
        
        infos[_ownedTokens[from][lastTokenIndex]].ownedposition        =  ownedposition;
        _ownedTokens[from][ownedposition]   =  _ownedTokens[from][lastTokenIndex];
    }

    /** token */
    function tokenURI(uint256 id_) public view virtual override returns (string memory) {
        require(_exists(id_), "ERC721Metadata: URI query for nonexistent token");
        if(bytes(URLs[id_]).length > 0)   return URLs[id_];
        string memory   baseURI = projects[infos[id_].proId].URI;
        uint            tokenId = infos[id_].proIndex;
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    } 
    function burn( uint256 id) external {
        require(msg.sender == ownerOf(id),"not owner");
        _burn(id);
    }
    
    /** for project */
    function opCreateProject( uint256 price_, address crypto_,string memory URI_, uint256 limit_) public chkOperator {
        Project memory vPro;
        vPro.price           = price_;
        vPro.crypto          = crypto_;
        vPro.URI             = URI_;
        vPro.limit          = limit_;
        projects.push(vPro);

        emit CreateProject(projects.length, projects.length -1, URI_);
    }
    function opMintProject(uint pId_, address to_, uint number_) external payable chkOperator {
        require( number_ > 0, "invalid receivers");
        require( number_ + projects[pId_].uCurrent <= projects[pId_].limit, "invalid token number");
        uint256 vCurrent = projects[pId_].uCurrent;

        for(uint256 vI = 0; vI < number_; vI++) {
            Info memory vInfo;
            vInfo.proId     =   pId_;
            vInfo.proIndex  =   vCurrent + vI;
            infos.push(vInfo);
            _mint(to_, tokenIdCurrent);
            tokenIdCurrent++;
        }
        projects[pId_].uCurrent  += number_;
        
        emit MintProject(pId_, number_, tokenIdCurrent-1, to_);
    }
    function mintProject(uint pId_, address to_, uint256 number_, uint256 amount_) external payable {
        require( number_ > 0, "invalid receivers");
        require( number_ + projects[pId_].uCurrent <= projects[pId_].limit, "invalid token number");
        require( amount_  == projects[pId_].price * number_,  "Amount sent is not correct");
        _cryptoTransferFrom(msg.sender, address(this), projects[pId_].crypto, amount_);
        uint256 vCurrent = projects[pId_].uCurrent;

        for(uint256 vI = 0; vI < number_; vI++) {
            Info memory vInfo;
            vInfo.proId     =   pId_;
            vInfo.proIndex  =   vCurrent + vI;
            infos.push(vInfo);
            _mint(to_, tokenIdCurrent);
            tokenIdCurrent++;
        }
        projects[pId_].uCurrent  += number_;
        projects[pId_].uIncome += amount_;
        emit MintProject(pId_, number_, tokenIdCurrent-1, to_);
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
    function owGetIncome(uint pId_) external chkOwnerLock {
        uint256 vAmount             = projects[pId_].uIncome;
        projects[pId_].uIncome      = 0;
        _cryptoTransfer(msg.sender, projects[pId_].crypto, vAmount);
    }
    function owGetCrypto(address crypto_, uint256 value_) public chkOwnerLock {
        _cryptoTransfer(msg.sender,  crypto_, value_);
    }
    function setOperator(address opr_, bool val_) public chkOwnerLock {
        _operators[opr_] = val_;
    }
}