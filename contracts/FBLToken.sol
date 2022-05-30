//SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FBL is ERC20 {
    struct Budget{
        string      name;
        uint256     budget;
        uint        withdrawDuration;
        uint256     withdrawable;
        uint        withdrawLast;
        uint256     withdrawTotal;
        address     receiver;
    }
    mapping(string => Budget)                       public budgets;

    constructor(Budget[] memory def_) ERC20 ("FootballBattle", "FBL") {   
        for(uint vI=0; vI< def_.length; vI++){
            string memory vName               = def_[vI].name;
            budgets[vName].name               = vName;
            budgets[vName].budget             = def_[vI].budget;
            budgets[vName].withdrawDuration   = def_[vI].withdrawDuration;
            budgets[vName].withdrawable       = def_[vI].withdrawable;
            budgets[vName].withdrawLast       = def_[vI].withdrawLast;
            budgets[vName].receiver           = def_[vI].receiver;        
        }        
    }
    function mintBudget(string memory name_) public {
        require(budgets[name_].withdrawTotal    + budgets[name_].withdrawable       <= budgets[name_].budget,"invalid budget");
        require(budgets[name_].withdrawLast     + budgets[name_].withdrawDuration   <= block.timestamp,"invalid duration");

        budgets[name_].withdrawLast     += budgets[name_].withdrawDuration;
        budgets[name_].withdrawTotal    += budgets[name_].withdrawable;
        _mint(budgets[name_].receiver, budgets[name_].withdrawable);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }
 
}
