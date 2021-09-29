// SPDX-License-Identifier: WTFPL
pragma solidity ^0.8.0;

import "./libraries/Ownable.sol";
import "./libraries/ERC165.sol";
import "./libraries/Address.sol";
import "./libraries/Strings.sol";
import "./libraries/SafeERC20.sol";
import "./libraries/NonFungibleToken.sol";

import "./interfaces/IERC721.sol";
import "./interfaces/IERC721Metadata.sol";
import "./interfaces/IERC721Receiver.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IUniqueBondDepository.sol";

// @author Dionysus
contract NonFungibleBondManager is NonFungibleToken("Olympus Bond", "BOND"), Ownable {

    /////////////// imports  ///////////////


    using SafeERC20 for IERC20;




    /////////////// storage  ///////////////


    // Mapping from token id to the bond id it represents
    mapping ( uint => uint ) public tokenToBond;

    // Mapping from token id to underlying bond depository
    mapping ( uint => address) public tokenToBondDepo;

    // Mapping that returns if an address is a valid bond depo
    mapping ( address => bool ) public whitelistedDepos;

    // Mapping containig an array of bids for each bond
    mapping ( uint => Bid[] ) public tokenBids;

    // Mappping containing the last redemption timestamp for each bond
    mapping ( uint => uint ) public lastRedeem;

    // count of NonFungible bonds that have been minted, used to get the next bond index within tokenToBond mapping
    uint public bondCount;




    /////////////// structs ///////////////


    struct Bid {
        address bidder;     // owner of the bid
        address principal;  // principal token used as payment
        uint amount;        // amount of principal being paid
        uint lastRedeem;    // used to determine if a bid is still valid or not
        bool refunded;      // has bidder refunded their bid
        uint deadline;      // time when bid is no longer acceptable
    }




    /////////////// events ///////////////


    event BondMinted ( 
        address bondDepo, 
        uint amount, 
        uint maxPrice, 
        address depositor, 
        uint tokenId, 
        uint bondId 
    );
    
    
    

    /////////////// policy  ///////////////


    function setValidDepo(address depo, bool isValid) external onlyPolicy() {
        whitelistedDepos[ depo ] = isValid;
    }


    /////////////// bond logic  ///////////////


    function deposit(
        address _bondDepo,
        uint _amount,
        uint _maxPrice,
        address _depositor
    ) external returns ( uint payout, uint tokenId, uint bondId ) {
        // make sure bond depo is valid
        require( whitelistedDepos[ _bondDepo ] == true, "invalid depo");
        // interface and deposit to bond depo
        (payout, bondId) = IUniqueBondDepository( _bondDepo ).deposit( _amount, _maxPrice, address( this ) );
        // mint user a NFT that represents their ownership of a unique bond
        _safeMint(_depositor, bondCount);
        // map the nft to the newly created bonds id 
        tokenToBond[bondCount] = bondId;
        // map the nft to its relevant depo for redeeming/tranfering ownership
        tokenToBondDepo[bondCount] = _bondDepo;
        // set tokenId and increment bondCount by one
        tokenId = bondCount;
        bondCount += 1;
        // emit event with relevant details
        emit BondMinted ( _bondDepo, _amount, _maxPrice, _depositor , tokenId, bondId);
    }

    function redeem( 
        uint _tokenId
    ) external returns ( uint payout, bool fullyVested ) {
        require( _exists( _tokenId ) );
        require( msg.sender == ownerOf[ _tokenId ], "You're not the owner");
        // redeem bond payout from relevent depository with payout sent to its owner
        ( payout, fullyVested ) = IUniqueBondDepository(tokenToBondDepo[ _tokenId ] ).redeem( tokenToBond[ _tokenId ], ownerOf[ _tokenId ] );
        // if fullyVested burn the bonds NFT
        if ( fullyVested ) _burn( _tokenId );
        // log the redemption time
        lastRedeem[ _tokenId ] = block.timestamp;
    }

    function bid(
        uint _tokenId,
        address _principal,
        uint _amount, 
        uint _deadline
    ) external {
        // make sure bond exists
        require( _exists( _tokenId ), "Bond doesn't exist" );
        // interface bonds bids array
        Bid[] storage bids = tokenBids[ _tokenId ];
        // push bid to storage
        bids.push(
            Bid({
                bidder: msg.sender,
                principal: _principal,
                amount: _amount, 
                lastRedeem: lastRedeem[ _tokenId ], 
                refunded: false,
                deadline: _deadline
            })
        );
        // transfer bid into escrow
        IERC20( _principal ).safeTransferFrom( msg.sender, address(this), _amount );
    }

    function acceptBid(
        uint _tokenId,
        uint _bidId
    ) external {
        // make sure bond exists
        require( _exists( _tokenId ), "Bond doesn't exist" );
        // make sure caller is owner of the bond
        require( msg.sender == ownerOf[ _tokenId ], "You're not the owner");
        // interface bonds array of bids
        Bid[] storage bids = tokenBids[ _tokenId ];
        // interface bid thats being accepted
        Bid storage acceptedBid = bids[ _bidId ];
        // ensure the bond hasn't been redeemed since the offer was created
        require( acceptedBid.lastRedeem == lastRedeem[ _tokenId ], "Bid's invalid");
        // transfer bid payment to bonds owner
        IERC20( acceptedBid.principal ).safeTransfer( ownerOf[ _tokenId ], acceptedBid.amount );
        // transfer bond to its new owner
        safeTransferFrom(ownerOf[ _tokenId ], acceptedBid.bidder, _tokenId);
    }

    function cancelBid(
        uint _tokenId,
        uint _bidId
    ) external {
        // make sure bond exists
        require( _exists( _tokenId ), "Bond doesn't exist" );
        // make sure caller is owner of the bond
        require( msg.sender == ownerOf[ _tokenId ], "You're not the owner");
        // interface bonds array of bids
        Bid[] storage bids = tokenBids[ _tokenId ];
        // interface bid thats being cancelled
        Bid storage _bid = bids[ _bidId ];
        // make sure caller is bidder
        require( msg.sender == _bid.bidder, "You're not the bidder for this bid");
        // mark the bid as refunded
        _bid.refunded = true;
        // transfer bid payment back to bidder
        IERC20( _bid.principal ).safeTransfer(_bid.bidder, _bid.amount);
    }
}
