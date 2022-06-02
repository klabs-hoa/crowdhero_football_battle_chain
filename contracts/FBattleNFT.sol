//SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract FBPlayer721 is ERC721 {
    using Strings for uint256;
    
    struct Project {
        string  URI;
        uint    limit;
        uint    uIdCurrent;
    }
    struct Info {
        uint    proId;
        uint    index;
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

    event CreateProject(uint indexed projectId, string URI);
    event MintProject(uint indexed projectId, uint indexed ind, uint256 tokenId,address[] backers);

    constructor( address[] memory operators_ ) ERC721 ("FootballBattle Player", "FBP") {
        _owner       = msg.sender;
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
    function opUpdateProject(uint pId_, string memory URI_) external chkOperator {
        projects[pId_].URI        = URI_;
    }
    function ownerTokens(address own_) external view returns(uint[][] memory) {
        uint256  vOwnerNum      = balanceOf(own_); 
        require(vOwnerNum > 0, "none NFT");
        uint[][] memory vTkns   = new uint[][](vOwnerNum);
        uint256 vTknId;
        for(uint256 vI = 1; vI <= vOwnerNum; vI++) {
            vTkns[vI-1]      = new uint[](3);
            vTknId           = _ownedTokens[own_][vI];
            vTkns[vI-1][0]   = vTknId;
            vTkns[vI-1][1]   = infos[vTknId].proId;
        }
        return vTkns;
    }
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);
        
        if (from != address(0)) { // transfrom + burn
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if((to != address(0)) && (from != address(0))) {  // transform
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
        uint            tokenId = infos[id_].index;
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    } 
    function burn( uint256 id) external {
        require(msg.sender == ownerOf(id),"not owner");
        _burn(id);
    }
    
    /** for project */
    function opCreateProject(string memory URI_, uint256 limit_) public chkOperator {
        Project memory vPro;
        vPro.URI             = URI_;
        vPro.limit          = limit_;
        projects.push(vPro);

        emit CreateProject(projects.length -1, URI_);
    }
    function opMintProject(uint pId_, address[] memory tos_, uint256 index_) external chkOperator {
        require( tos_.length > 0, "invalid receivers");
        require( tos_.length + projects[pId_].uIdCurrent <= projects[pId_].limit, "invalid token number");
        
        uint256 vLength = balanceOf(to)+1;
        for(uint256 vI = 0; vI < tos_.length; vI++) {
            Info memory vInfo;
            vInfo.proId     =   pId_;
            vInfo.index     =   index_ + vI;
            vInfo.ownedposition = length;
            infos.push(vInfo);
            _ownedTokens[to][vLength] = tokenIdCurrent;
            _mint(tos_[vI], tokenIdCurrent);
            tokenIdCurrent++;
            vLength++;
        }
        projects[pId_].uIdCurrent  += tos_.length;
       
        emit MintProject(pId_, index_, tokenIdCurrent-1, tos_);
    }
    
    function setOperator(address opr_, bool val_) public chkOwnerLock {
        _operators[opr_] = val_;
    }
}