pragma solidity ^0.8;

contract teste{
    uint [3] valores = [1,2,3];

    function getLength() public view returns(uint){
        return valores.length;
    }
}