// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./EventToken.sol";

contract EVENTMarketplace is Ownable
{
    event log(string) ; 
    
    // CHANGE BELOW ADDRESS to the real one deployed token address 
    EVENTToken public token;
    
    uint public constant tokensReward = 10 ; 
    uint public constant tokensPenalty = 20 ; 

    struct Buyer
    {
        uint qtyBought ; 
        uint priceBought ; 
    }

    Buyer public thisBuyer ; 

    struct Ticket 
    {
        uint id;
        string Description ;
        uint maxBuyPerWallet ;
        uint originalPrice ; 
        uint askPrice ; // current market spot price 
        uint tokensRewardOverride ; 
        uint tokensPenaltyOverride ; 
        address seller ; 
        uint qtyAvailable ; 
        // mapping (address => buyer) buyers ; 
    }
        
    Ticket[] public tickets ; 
    Ticket public oneTicket ; 

    // mapping (address => Buyer[]) tks ; 

    struct User 
    {
        uint joinedOn ; // when user joined the platform, unix timestamp
        uint qtyTicketsPurchased ;
        uint qtyTicketsSold ; 
        uint sellerRating ; 
        uint buyerRating ; 
    }

    mapping (uint => Buyer[]) public ticketBuyers;   // ticketId => Buyers[]
    mapping (address => User) public wallets ; 


    constructor (address _tokenAddress) Ownable(){
        token = EVENTToken(_tokenAddress);
    }    

    function buy(uint _ticketID, uint _price, address _buyer, uint _qty) public returns (bool)
    // 0, 300, 0x692a70d2e424a56d2c6c27aa97d1a86395877b3a, 3
    {
        // make sure there are enough tickets available to sell 
        require( tickets[_ticketID].qtyAvailable > 0 ) ;
        require ( _qty > 0 ) ; 
        require ( (tickets[_ticketID].qtyAvailable - _qty) >= 0 ) ; 
        require( _price >= tickets[_ticketID].askPrice ) ;
        //  TODO
        // require ( (tickets[_ticketID].buyers[_buyer].qtyBought + _qty) <= tickets[_ticketID].maxBuyPerWallet ) ; 
        emit log("1"); 

        // selling price higher than original price --> penalize seller burning tokens  
        if (_price > tickets[_ticketID].originalPrice ) 
        {
            uint penalty ; 
            emit log("2") ; 
            if (tokensPenalty > tickets[_ticketID].tokensPenaltyOverride )
                penalty = tokensPenalty ; 
            else penalty = tickets[_ticketID].tokensPenaltyOverride ; 

            require (token.balanceOf(tickets[_ticketID].seller) > penalty )  ;
            emit log("3");   
            // tokens from seller are burnt
            // Tuan
            // require (token.burn(penalty,tickets[_ticketID].seller)); 
            token.burn(penalty,tickets[_ticketID].seller);
            emit log("4"); 
        }

        // selling price lower than original price --> reward seller w/ tokens 
        if (_price < tickets[_ticketID].originalPrice ) 
        {
            emit log("5"); 
            
            uint reward ; 
            if (tokensReward > tickets[_ticketID].tokensRewardOverride )  
                reward = tokensReward ; 
            else reward = tickets[_ticketID].tokensRewardOverride ; 
            // Tuan
            token.mint(tickets[_ticketID].seller,reward);
            // require (token.mint(tickets[_ticketID].seller,reward)); 
        }

        // selling price same as original price --> nothing happens 
        if (_price == tickets[_ticketID].originalPrice ) { 
            emit log("6"); 
        }

        // records the sell 
        tickets[_ticketID].qtyAvailable = tickets[_ticketID].qtyAvailable - _qty ; 
        //  TODO
        // tickets[_ticketID].buyers[_buyer].qtyBought = tickets[_ticketID].buyers[_buyer].qtyBought + _qty ; 
        // tickets[_ticketID].buyers[_buyer].priceBought = _price ; 

        // reward buyer with tokens for the current transaction 
        require( rewardBuyer(_buyer,_qty) ) ; 
        emit log ("7") ; 

        // updates user's wallets stats 
        wallets[_buyer].qtyTicketsPurchased = wallets[_buyer].qtyTicketsPurchased + _qty ; 

        wallets[tickets[_ticketID].seller].qtyTicketsSold = 
        wallets[tickets[_ticketID].seller].qtyTicketsSold + _qty ; 

        return true  ; 

    } // END OF buy() 

    function rateBuyer(address _buyer, uint _rating) onlyOwner public returns (bool)
    {
        require(_rating >= 1 && _rating <=5);
        require (wallets[_buyer].qtyTicketsPurchased > 0) ; 

        // ( currentScore * (TotalQty -1) + _rating ) / TotalQty 
        uint score ; 

        if (wallets[_buyer].buyerRating == 0 ) score = _rating ; 
        else 
            score = ( ( wallets[_buyer].buyerRating * (wallets[_buyer].qtyTicketsPurchased - 1) ) 
                    + _rating ) / wallets[_buyer].qtyTicketsPurchased ; 

        wallets[_buyer].buyerRating = score ; 

        return true ; 
    }


    function rateSeller(address _seller, uint _rating) onlyOwner public returns (bool)
    {
        require(_rating >= 1 && _rating <=5);
        require ( wallets[_seller].qtyTicketsSold >= 1) ; 


        // ( currentScore * (TotalQty -1) + _rating ) / TotalQty 
        uint score ; 

        if (wallets[_seller].sellerRating == 0 ) score = _rating ; 
        else 
            score = ( ( wallets[_seller].sellerRating * (wallets[_seller].qtyTicketsSold - 1) ) 
                    + _rating ) / wallets[_seller].qtyTicketsSold ; 


        wallets[_seller].sellerRating = score ; 

        return true ; 
    }


    function rewardBuyer(address _buyer, uint _qty ) internal returns (bool)
    {
    
        uint reward = wallets[_buyer].qtyTicketsPurchased + (2 * _qty) ; 
        reward = reward + (token.balanceOf(_buyer) * 2) ; 
        //  Tuan
        token.mint(_buyer,reward);
        // require(token.mint(_buyer,reward));

        return true ; 

    }


    function uploadTicket(
        string memory _Description, 
        uint  _maxBuyPerWallet,
        uint  _originalPrice, uint  _askPrice, uint  _tokensRewardOverride, 
        uint  _tokensPenaltyOverride,  
        address  _seller, uint  _qtyAvailable) public returns (uint)
    {

        require( _qtyAvailable > 0 );
        require( _maxBuyPerWallet > 0 ) ; 
        require( _seller != address(0) ) ;  

        // "test",1,1,1,1,1, 0xca35b7d915458ef540ade6068dfe2f44e8fa733c,1
        // "Metallica",2,250,300,30,30, 0xca35b7d915458ef540ade6068dfe2f44e8fa733c,100


        oneTicket.id = tickets.length + 1;
        oneTicket.Description = _Description;
        oneTicket.maxBuyPerWallet = _maxBuyPerWallet;
        oneTicket.originalPrice = _originalPrice; 
        oneTicket.askPrice = _askPrice; // current market spot price 
        oneTicket.tokensRewardOverride = _tokensRewardOverride; 
        oneTicket.tokensPenaltyOverride = _tokensPenaltyOverride; 
        oneTicket.seller = _seller; 
        oneTicket.qtyAvailable = _qtyAvailable; 

        tickets.push(oneTicket) ; 

        // thisBuyer = buyer(100,50) ;

        // tickets[ticketsLength()-1].
        // buyers[0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c] = thisBuyer ; 


        return (tickets.length -1) ; 
    }

    function ticketsLength() public view returns (uint) { 
        return tickets.length ; 
    }

    function  priceOfATicket(uint _ticketID, address _address) public view  returns (uint)
    { 
        //  TODO
        return 0;
        // return  tickets[_ticketID].buyers[_address].priceBought ; 
    }


    function userJoins(address _user) onlyOwner public returns(uint) { 
        // wallets[_user].joinedOn = now ; 
        wallets[_user].joinedOn = block.timestamp; 
        return wallets[_user].joinedOn;
    } 
} // END OF EVENTMarketplace

