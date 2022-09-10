// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./EventToken.sol";
import "hardhat/console.sol";

contract EVENTMarketplace is Ownable
{
    // CHANGE BELOW ADDRESS to the real one deployed token address 
    EVENTToken public token;
    
    uint public constant tokensReward = 10 ; 
    uint public constant tokensPenalty = 20 ; 

    struct Buyer
    {
        uint qtyBought ; 
        uint priceBought ; 
    }

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
    }
        
    struct Trade
    {
        uint id;
        uint ticketId;
        uint price ; 
        uint qty ;
        uint tradeAt ;
        address seller ; 
        address buyer ; 
    }
        
    mapping(uint => Ticket) public tickets; //  ticketId => Ticket
    mapping(uint => Trade) public trades; //  tradeId => Ticket

    // Ticket public oneTicket ; 
    uint public ticketCount;
    uint public tradeCount;

    struct User 
    {
        uint joinedOn ; // when user joined the platform, unix timestamp
        uint qtyTicketsPurchased ;
        uint qtyTicketsSold ; 
        uint sellerRating ; 
        uint buyerRating ; 
    }

    mapping (address => User) public wallets ; 


    constructor (address _tokenAddress) Ownable(){
        token = EVENTToken(_tokenAddress);
        ticketCount = 0;
        tradeCount = 0;
    }    

    function _getTotalBoughtByBuyer(uint _ticketID, address _buyer) private view returns (uint) {
        console.log("_getTotalBoughtByBuyer _ticketID", _ticketID);        
        console.log("_getTotalBoughtByBuyer tradeCount ", tradeCount);        
        uint total = 0;
        for (uint id = 1; id <= tradeCount; id++) {
            Trade memory trade = trades[id];
            // console.log("_getTotalBoughtByBuyer ", trade.ticketId, trade.buyer, _buyer);        
            console.log("_getTotalBoughtByBuyer ", trade.ticketId);        
            if (trade.ticketId == _ticketID && trade.buyer == _buyer) {
                total += trade.qty;
                console.log("_getTotalBoughtByBuyer here total ", total);        
            }
            console.log("_getTotalBoughtByBuyer final total  ", total);        
        }                

        return total;
    }

    function buy(uint _ticketID, uint _price, address _buyer, uint _qty) public returns (bool)
    {
        // make sure there are enough tickets available to sell 
        require( tickets[_ticketID].qtyAvailable > 0, "Invalid available quantity" ) ;
        require ( _qty > 0, "Invalid buy quantity" ) ; 

        console.log("_qty ", _qty);        
        console.log("tickets[_ticketID].qtyAvailable ", tickets[_ticketID].qtyAvailable);        
        require ( tickets[_ticketID].qtyAvailable >= _qty, "Not enough available quantity" ) ; 
        require( _price >= tickets[_ticketID].askPrice, "Price does not meet askPrice" ) ;
        uint totalBoughtByBuyer = _getTotalBoughtByBuyer(_ticketID, _buyer);

        console.log("totalBoughtByBuyer ", totalBoughtByBuyer);        
        console.log("tickets[_ticketID].maxBuyPerWallet ", tickets[_ticketID].maxBuyPerWallet);        
        require(totalBoughtByBuyer + _qty <= tickets[_ticketID].maxBuyPerWallet, "Exceed maxBuyPerWallet");

        // selling price higher than original price --> penalize seller burning tokens  
        console.log("tickets[_ticketID].originalPrice ", tickets[_ticketID].originalPrice);        
        if (_price > tickets[_ticketID].originalPrice ) 
        {
            uint penalty ; 

            console.log("tickets[_ticketID].tokensPenaltyOverride  ", tickets[_ticketID].tokensPenaltyOverride);        
            if (tokensPenalty > tickets[_ticketID].tokensPenaltyOverride )
                penalty = tokensPenalty ; 
            else penalty = tickets[_ticketID].tokensPenaltyOverride ; 
            console.log("penalty ", penalty);        
            console.log("token.balanceOf(tickets[_ticketID].seller) ", token.balanceOf(tickets[_ticketID].seller));        

            require (token.balanceOf(tickets[_ticketID].seller) > penalty, "Seller token balance is less than penalty" )  ;
            // tokens from seller are burnt
            //  TODO: 
            // require (token.burn(penalty,tickets[_ticketID].seller)); 
            token.burn(penalty,tickets[_ticketID].seller);
        }

        // selling price lower than original price --> reward seller w/ tokens 
        if (_price < tickets[_ticketID].originalPrice ) 
        {            
            uint reward ; 
            if (tokensReward > tickets[_ticketID].tokensRewardOverride )  
                reward = tokensReward ; 
            else reward = tickets[_ticketID].tokensRewardOverride ; 
            //  TODO: 
            token.mint(tickets[_ticketID].seller,reward);
            // require (token.mint(tickets[_ticketID].seller,reward)); 
        }

        // selling price same as original price --> nothing happens 
        // if (_price == tickets[_ticketID].originalPrice ) { 
        // }

        // records the sell 
        tickets[_ticketID].qtyAvailable = tickets[_ticketID].qtyAvailable - _qty ; 

        // create ticket instance
        // struct Trade
        // {
        //     uint id;
        //     uint ticketId;
        //     uint price ; 
        //     uint qty ;
        //     uint tradeAt ;
        //     address seller ; 
        //     address buyer ; 
        // }

        tradeCount ++;
        uint tradeId = tradeCount;
        Trade memory newTrade = Trade(
            tradeId,
            _ticketID,
            _price,
            _qty,
            block.timestamp,
            tickets[_ticketID].seller,
            _buyer
        );

        trades[tradeId] = newTrade;

        // reward buyer with tokens for the current transaction 
        //  TODO: 
        // require( rewardBuyer(_buyer,_qty), "Fail to reward buyer" ) ; 

        // updates user's wallets stats 
        wallets[_buyer].qtyTicketsPurchased = wallets[_buyer].qtyTicketsPurchased + _qty ; 

        wallets[tickets[_ticketID].seller].qtyTicketsSold = wallets[tickets[_ticketID].seller].qtyTicketsSold + _qty ; 

        return true  ; 
    } // END OF buy() 

    function rateBuyer(address _buyer, uint _rating) onlyOwner public returns (bool)
    {
        require(_rating >= 1 && _rating <=5, "rate should be in range from 1 to 5");
        require (wallets[_buyer].qtyTicketsPurchased > 0, "buyer did not buy any ticket") ; 

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
        require(_rating >= 1 && _rating <=5, "rate should be in range from 1 to 5");
        require ( wallets[_seller].qtyTicketsSold >= 1, "Seller did not sell any ticket") ; 


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
        //  TODO: 
        token.mint(_buyer,reward);
        // require(token.mint(_buyer,reward));

        return true ; 

    }


    function uploadTicket(
        string memory _Description, 
        uint  _maxBuyPerWallet,
        uint  _originalPrice, 
        uint  _askPrice, 
        uint  _tokensRewardOverride, 
        uint  _tokensPenaltyOverride,  
        address  _seller, 
        uint  _qtyAvailable) public returns (uint)
    {

        console.log("Start uploading");
        require( _qtyAvailable > 0, "qtyAvailable must not be 0" );
        require( _maxBuyPerWallet > 0, "maxBuyPerWallet must not be 0" ) ; 
        require( _seller != address(0), "seller is not valid" ) ;  

        // "test",1,1,1,1,1, 0xca35b7d915458ef540ade6068dfe2f44e8fa733c,1
        // "Metallica",2,250,300,30,30, 0xca35b7d915458ef540ade6068dfe2f44e8fa733c,100

        ticketCount ++;
        
        // struct Ticket 
        // {
        //     uint id;
        //     string Description ;
        //     uint maxBuyPerWallet ;
        //     uint originalPrice ; 
        //     uint askPrice ; // current market spot price 
        //     uint tokensRewardOverride ; 
        //     uint tokensPenaltyOverride ; 
        //     address seller ; 
        //     uint qtyAvailable ; 
        // }
        Ticket memory newTicket = Ticket(
            ticketCount,
            _Description,
            _maxBuyPerWallet,
            _originalPrice,
            _askPrice,
            _tokensRewardOverride,
            _tokensPenaltyOverride,
            _seller,
            _qtyAvailable
        );

        tickets[newTicket.id] = newTicket;

        // thisBuyer = buyer(100,50) ;

        // tickets[ticketsLength()-1].
        // buyers[0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c] = thisBuyer ; 

        console.log("Uploaded, newTicket.id ", newTicket.id);
        console.log("_seller ", _seller);
        return newTicket.id; 
    }

    //  No need!!!
    // function  priceOfATicket(uint _ticketID, address _address) public view  returns (uint)
    // { 
    //     return  tickets[_ticketID].buyers[_address].priceBought ; 
    // }

    function userJoins(address _user) onlyOwner public returns(uint) { 
        console.log("userJoins");
        wallets[_user].joinedOn = block.timestamp; 
        return wallets[_user].joinedOn;
    } 
} // END OF EVENTMarketplace

