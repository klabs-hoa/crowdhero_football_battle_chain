//SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract FootballBattle721 is ERC721 {
    using Strings for uint256;
    
    struct Project {
        uint    fundId;
        address creator;
        uint256 mintPrice;      // use USD
        uint256 mintFee;        // use USD
        uint256 transferFee;    // use FBL
        string  URI;
        uint    uLimit;
        uint256 uMintIncome;    // use USD
        uint256 uMintTax;       // use USD
        uint256 uTransferTax;   // use FBL
        uint    uIdCurrent;
    }
    struct Info {
        uint    proId;
        uint    index;
    }
    address                                         private _tokenUSD;
    address                                         private _tokenFBL;

    uint256                                         public  tokenIdCurrent;
    Project[]                                       public  projects;
    Info[]                                          public  infos;          
    mapping(uint    =>  string)                     private URLs;

    mapping(address =>  bool)                       private _operators;
    address                                         private _owner;
    bool                                            private _ownerLock = true;

    event CreateProject(uint indexed fundId, uint indexed projectId, string URI);
    event MintProject(uint indexed projectId, uint indexed ind, uint256 tokenId,address[] backers);

    constructor(string memory name_, string memory symbol_,  address[] memory operators_ ) ERC721 (name_, symbol_) {
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
    function opUpdateProject(uint pId_, uint256 mintPrice_, uint256 mintFee_, uint256 transferFee_,string memory URI_) external chkOperator {
        projects[pId_].mintPrice        = mintPrice_;
        projects[pId_].mintFee          = mintFee_;
        projects[pId_].URI              = URI_;
        projects[pId_].transferFee      = transferFee_;
    }
    function ownerTokens(address own_) external view returns(uint[][] memory) {
        require(balanceOf(own_) > 0, "none NFT");
        uint[][] memory vTkns = new uint[][](balanceOf(own_));
        uint vTo;
        for(uint256 vI = 0; vI <= tokenIdCurrent; vI++) {
           if(ownerOf(vI) == own_) {
                vTkns[vTo]      = new uint[](3);
                vTkns[vTo][0]   = vI;
                vTkns[vTo][1]   = infos[vI].proId;
                vTkns[vTo][2]   = projects[infos[vI].proId].fundId;
                vTo++;
           } 
           if(vTo == balanceOf(own_)) break;
        }
        return vTkns;
    }
    /** token */
    function tokenURI(uint256 id_) public view virtual override returns (string memory) {
        require(_exists(id_), "ERC721Metadata: URI query for nonexistent token");
        if(bytes(URLs[id_]).length > 0)   return URLs[id_];
        string memory   baseURI = projects[infos[id_].proId].URI;
        uint            tokenId = infos[id_].index;
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    } 
    function burn( uint256 id) external {
        _burn(id);
    }
    
    /** for project */
    function opCreateProject(uint fundId_, address creator_, uint256 mintPrice_, uint256 mintFee_, uint256 transferFee_, string memory URI_, uint256 limit_) public chkOperator {
        Project memory vPro;
        vPro.fundId          = fundId_;
        vPro.creator         = creator_;
        vPro.mintPrice       = mintPrice_;
        vPro.mintFee         = mintFee_;
        vPro.transferFee     = transferFee_;
        vPro.URI             = URI_;
        vPro.uLimit          = limit_;
        projects.push(vPro);

        emit CreateProject(fundId_, projects.length -1, URI_);
    }
    function opMintProject(uint pId_, address[] memory tos_, uint256 index_, uint256 amount_) external payable chkOperator {
        require( tos_.length <= projects[pId_].uLimit, "invalid token number");
        require( amount_  == projects[pId_].mintPrice * tos_.length,  "Amount sent is not correct");
        _cryptoTransferFrom(msg.sender, address(this), _tokenUSD, amount_);
       
        for(uint256 vI = 0; vI < tos_.length; vI++) {
            _mint(tos_[vI], tokenIdCurrent);
            tokenIdCurrent++;
            Info memory vInfo;
            vInfo.proId     =   pId_;
            vInfo.index     =   index_ + vI;
            infos.push(vInfo);
        }
        projects[pId_].uLimit           -= tos_.length;
        projects[pId_].uIdCurrent       += tos_.length;
        if(amount_ > 0) {
            uint256 vFee                =  projects[pId_].mintFee * tos_.length;
            projects[pId_].uMintTax     += vFee;
            projects[pId_].uMintIncome  += amount_ - vFee;
        }
        emit MintProject(pId_, index_, tokenIdCurrent-1, tos_);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        _cryptoTransfer(from, _tokenFBL, projects[infos[tokenId].proId].transferFee);
        projects[infos[tokenId].proId].uTransferTax  += projects[infos[tokenId].proId].transferFee;      
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

/** for creator */        
    function withdraw(uint pId_) external {
        require(projects[pId_].creator == msg.sender, "only for creator");
        uint256 vAmount                     = projects[pId_].uMintIncome;
        projects[pId_].uMintIncome         = 0;
        _cryptoTransfer(msg.sender, _tokenUSD, vAmount);
    }
/** for owner */   
    function owGetTaxUSD(uint pId_) external chkOwnerLock {
        uint256 vAmount                 = projects[pId_].uMintTax;
        projects[pId_].uMintTax         = 0;
        _cryptoTransfer(msg.sender, _tokenUSD, vAmount);
    }
    function owGetTaxFBL(uint pId_) external chkOwnerLock {
        uint256 vAmount                 = projects[pId_].uTransferTax;
        projects[pId_].uTransferTax     = 0;
        _cryptoTransfer(msg.sender, _tokenFBL, vAmount);
    }
    function owGetCrypto(address crypto_, uint256 value_) public chkOwnerLock {
        _cryptoTransfer(msg.sender,  crypto_, value_);
    }
/** for test */   
    function testSetOperator(address opr_, bool val_) public {
        _operators[opr_] = val_;
    }
    function testToken(address tokenUSD_, address tokenFBL_) public {
        _tokenUSD   = tokenUSD_;
        _tokenFBL   = tokenFBL_;
    }    
}
