// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external;
    function approve(address _spender, uint _value) external;
    function transferFrom(address _from, address _to, uint _value) external;

}

contract MagicTickets{

    address public owner;

    constructor() {
        owner = msg.sender;
    }

    address payable walletSite = payable(0x555a2d86B9d4A89D61a2Df3C6BfC7006ad6aa2cF);

    enum STATUS {
        STARTED,
        ENDED,
        CANCELED
    }

    event createdRaffle(uint indexed raffleID, address indexed seller);
    event canceledRaffle(uint indexed raffleID);
    event boughtTickets(uint indexed raffleID, uint indexed quantity, address indexed buyer);
    event drawWinner(uint indexed raffleID, address indexed winner);

    struct RaffleStruct {
        STATUS _status;
        uint _maxEntries;
        uint _minTickets;
        uint _amountEth;
        address _seller;
        uint _amountRaised;
        address _winner;
        uint _qtdDisponivel;
        uint _sitePercentage;
        address _tokenRaffle;
        uint _ticketValue;
        address _tokenReceived;
    }

    // The main structure is an array of raffles
    RaffleStruct[] public raffles;

    struct Entry{
        address _player;
    }

    mapping (uint => Entry[]) public entries;

    function transferTokens(address _token ,address _from, address _to, uint _amount) private{

        IERC20 raffleToken = IERC20(_token);
        raffleToken.transferFrom(_from, _to, _amount);
    }

    function createRaffle(uint amount, 
    uint maxEntries, 
    uint minTickets, 
    address tokenRaffle, 
    address seller, uint ticketValue, address tokenReceived) public returns(uint){
        require(amount > 0, "O valor pago nao pode ser 0");
        require(maxEntries > 0, "A quantidade de tickets nao pode ser 0");
        require(minTickets > 0, "A quantidade minima de tickets nao pode ser 0");

        transferTokens(tokenRaffle, seller, address(this), amount);

        RaffleStruct memory raffle = RaffleStruct({
            _maxEntries: maxEntries,
            _minTickets: minTickets,
            _amountEth: amount,
            _seller: seller,
            _amountRaised: 0,
            _winner: address(0),
            _qtdDisponivel: maxEntries,
            _status: STATUS.STARTED,
            _sitePercentage: 0,
            _tokenRaffle: tokenRaffle,
            _ticketValue: ticketValue,
            _tokenReceived: tokenReceived
        });

        raffles.push(raffle);

        emit createdRaffle(raffles.length - 1, msg.sender);

        return raffles.length - 1;
    }

    function getQtdDisponivel(uint _id) public view returns(uint){
        return raffles[_id]._qtdDisponivel;
    }

    function buyEntry(uint _id, uint qtd, address buyer, address _tokenPay) public{
        require(raffles[_id]._maxEntries - entries[_id].length >= qtd, "qtd indisponivel");
        require(buyer != raffles[_id]._seller, "O seller nao pode comprar entradas do proprio sorteio");

        uint value = raffles[_id]._ticketValue * qtd;
        
        IERC20 tokenPay = IERC20(_tokenPay);
        tokenPay.transferFrom(msg.sender, address(this), value);

        Entry memory entry = Entry({
            _player: buyer
        });

        for( uint i = 0; i < qtd; i++){
            entries[_id].push(entry);
        }

        raffles[_id]._amountRaised += value;
        raffles[_id]._qtdDisponivel -= qtd;

        emit boughtTickets(_id, qtd, buyer);
    }

    function gerarNumero(string calldata semente, uint range) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, semente))) % (range + 1);
    }

    function sortearWinner(uint _id, string calldata seed) public {
        require(msg.sender == owner, "Voce nao pode realizar o sorteio");        
        RaffleStruct storage raffle = raffles[_id];

        require(raffle._status != STATUS.ENDED && raffle._status != STATUS.CANCELED, "O Raffle ja foi finalizado");
        require(entries[_id].length >= raffle._minTickets, "Quantidade de tickets insuficiente");
        
        uint256 valor = gerarNumero(seed, entries[_id].length);

        address wallet = entries[_id][valor]._player;

        raffle._winner = wallet;

        raffle._status = STATUS.ENDED;

        emit drawWinner(_id, raffle._winner);

        sendToken(_id);

    }

    function cancelRaffle(uint _id) public{
        require(msg.sender == raffles[_id]._seller, "Voce nao tem permissao para realizar essa acao");
        require(entries[_id].length == 0, "Voce nao pode mais cancelar esse raffle");

        RaffleStruct storage raffle = raffles[_id];

        require(raffle._status == STATUS.STARTED, "Este raffle ja nao esta mais ocorrendo");
        
        address wallet = raffle._seller;

        IERC20 tokenRaffle = IERC20(raffle._tokenRaffle);

        tokenRaffle.transfer(wallet, raffle._amountEth);

        raffle._status = STATUS.CANCELED;

        emit canceledRaffle(_id);
    }

    function devolution(uint _id) public{
        require(msg.sender == owner, "Apenas o owner pode realizar a devolucao");
        RaffleStruct storage raffle = raffles[_id];

        IERC20 token = IERC20(raffle._tokenRaffle);

        token.transfer(raffle._seller, raffle._amountEth);

        raffle._status = STATUS.ENDED;
    }

    function sendToken(uint _id) private {

        RaffleStruct memory raffle = raffles[_id];

        IERC20 tokenRaffle = IERC20(raffle._tokenRaffle);
        raffle._sitePercentage = raffle._amountRaised/100;
        uint valueSeller = raffle._amountRaised - raffle._sitePercentage;


        tokenRaffle.transfer(raffle._winner, raffle._amountEth);

        // address payable walletSeller = payable(raffle._seller);

        IERC20 tokenReceived = IERC20(raffle._tokenReceived);
        tokenReceived.transfer(raffle._seller, valueSeller);
        tokenReceived.transfer(walletSite ,raffle._sitePercentage);
    }
}