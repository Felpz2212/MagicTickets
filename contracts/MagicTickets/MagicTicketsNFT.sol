//// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IERC721{
    function balanceOf(address _owner) external view returns (uint256);
    function ownerOf(uint256 _tokenId) external view returns (address);
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory data) external payable;
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;
    function transferFrom(address _from, address _to, uint256 _tokenId) external payable;
    function approve(address _approved, uint256 _tokenId) external payable;
    function setApprovalForAll(address _operator, bool _approved) external;
    function getApproved(uint256 _tokenId) external view returns (address);
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);

}

interface IERC20 {
    function transfer(address recipient, uint256 amount) external;
    function approve(address _spender, uint _value) external;
    function transferFrom(address _from, address _to, uint _value) external;

}

contract MagicNFT {

    address public owner;

    constructor (){
        owner = msg.sender;
    }

    enum STATUS{
        STARTED,
        ENDED,
        CANCELED
    }

    event createdRaffle(uint indexed raffleID, address indexed seller);
    event canceledRaffle(uint indexed raffleID);
    event boughtTickets(uint indexed raffleID, uint indexed quantity, address indexed buyer);
    event drawWinner(uint indexed raffleID, address indexed winner);

    struct RaffleStruct{
        STATUS status;
        uint maxEntries;
        uint minTickets;
        uint amountRaised;
        uint qtdAvailable;
        uint sitePercentage;
        uint ticketValue;
        address tokenReceived;
        uint tokenNFT;
        address tokenContract;
        address seller;
        address winner;
    }

    RaffleStruct[] public raffles;

    struct Entry {
        address player;
    }

    mapping(uint => Entry[]) public entries;

    function transferNFT (uint _tokenID, address _NFTContract, address _from) private {
        IERC721 nft = IERC721(_NFTContract);
        nft.transferFrom(_from, address(this), _tokenID);
    }

    function createRaffle(uint _maxEntries, uint _minTickets, 
    address _tokenContract, uint _tokenID, uint _ticketValue, address _tokenReceived) public returns(uint){
        require(_maxEntries > 0, " A ");
        require(_minTickets > 0, " B ");
        require(_tokenContract != address(0), " C ");
        require(_tokenID >= 0, " D ");
        require(_tokenReceived != address(0), " E ");
        require(_ticketValue > 0, " F ");

        transferNFT(_tokenID, _tokenContract, msg.sender);
        RaffleStruct memory raffle = RaffleStruct({
            maxEntries: _maxEntries,
            minTickets: _minTickets,
            amountRaised: 0,
            qtdAvailable: _maxEntries,
            status: STATUS.STARTED,
            sitePercentage: 0,
            ticketValue: _ticketValue,
            seller: msg.sender,
            tokenReceived: _tokenReceived,
            tokenContract: _tokenContract,
            tokenNFT: _tokenID,
            winner: address(0)
        });

        raffles.push(raffle);

        emit createdRaffle(raffles.length - 1, msg.sender);

        return raffles.length - 1;
    } 

    function buyTickets(uint _qtd, uint _id, address _buyer) public {
        require(raffles[_id].maxEntries - entries[_id].length >= _qtd, "qtd indisponivel");
        require(_buyer != raffles[_id].seller, "O seller nao pode comprar entradas do proprio sorteio");

        uint value = raffles[_id].ticketValue * _qtd;

        IERC20 token = IERC20(raffles[_id].tokenReceived);
        token.transferFrom(msg.sender, address(this), value);

        Entry memory entry = Entry({
            player: _buyer
        });

        for( uint i = 0; i < _qtd; i++){
            entries[_id].push(entry);
        }

        raffles[_id].amountRaised += value;
        raffles[_id].qtdAvailable -= _qtd;

        emit boughtTickets(_id, _qtd, _buyer);
        
    }

    function getQtdDisponivel(uint _id) public view returns(uint){
        return raffles[_id].qtdAvailable;
    }

    function cancelRaffle(uint _id) public {
        require(msg.sender == raffles[_id].seller, " ");
        require(entries[_id].length == 0, " ");

        RaffleStruct storage raffle = raffles[_id];

        require(raffle.status == STATUS.STARTED, " ");

        address wallet = raffle.seller;

        IERC721 nft = IERC721(raffle.tokenContract);
        nft.transferFrom(address(this), wallet, raffle.tokenNFT);

        raffle.status = STATUS.CANCELED;

        emit canceledRaffle(_id);
    }

    function devolution(uint _id) public{
        require(msg.sender == owner, "Apenas o owner pode realizar a devolucao");
        RaffleStruct storage raffle = raffles[_id];

        IERC721 nft = IERC721(raffle.tokenContract);

        nft.transferFrom(address(this), raffle.seller, raffle.tokenNFT);

        raffle.status = STATUS.ENDED;
    }

    function gerarNumero(string calldata semente, uint range) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, semente))) % (range + 1);
    }

    function sortearWinner(uint _id, string calldata seed) public {
        require(msg.sender == owner, "Apenas o owner pode realizar a chamada dessa funcao");

        RaffleStruct storage raffle = raffles[_id];

        require(raffle.status != STATUS.ENDED && raffle.status != STATUS.CANCELED, "O Raffle ja foi finalizado");
        require(entries[_id].length >= raffle.minTickets, "Quantidade de tickets insuficientes");

        uint valor = gerarNumero(seed, entries[_id].length - 1);
        address wallet = entries[_id][valor].player;

        raffle.winner = wallet;
        raffle.status = STATUS.ENDED;

        emit drawWinner(_id, raffle.winner);

        sendTokenAndNFT(_id);
    }


    function sendTokenAndNFT(uint _id) private{
        RaffleStruct memory raffle = raffles[_id];

        IERC20 tokenRaffle = IERC20(raffle.tokenReceived);
        raffle.sitePercentage = raffle.amountRaised/100;
        uint valueSeller = raffle.amountRaised - raffle.sitePercentage;

        tokenRaffle.transfer(raffle.seller, valueSeller);

        IERC721 nft = IERC721(raffle.tokenContract);
        nft.transferFrom(address(this), raffle.winner, raffle.tokenNFT);
    }
}
