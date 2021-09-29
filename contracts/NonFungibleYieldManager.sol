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
import "./interfaces/IwsOHM.sol";

// @author Dionysus
contract NonFungibleYeildManager is Ownable, NonFungibleToken("Olympus Yield Token", "YI3LD") {

    /////////// imports ///////////

    using SafeERC20 for IERC20;



    /////////// structs ///////////

    struct Receipt {
        address depositor;
        uint amount;
        uint vestingTerm;
        uint inititialStakedOhmValue;
    }

    struct Bid {
        address bidder;     // owner of the bid
        address principal;  // principal token used as payment
        uint amount;        // amount of principal being paid
        bool refunded;      // has bidder refunded their bid
        uint deadline;      // time when bid is no longer acceptable
    }



    /////////// storage ///////////

    IwsOHM public wsOHM;

    IStaking public staking;

    uint public tokenCount;

    mapping( uint => Receipt ) tokenToReceipt;

    // Mapping containig an array of bids for each token
    mapping ( uint => Bid[] ) public tokenBids;

    ///////////  user  ///////////

    function deposit(
        address depositor,
        uint amount,
        uint vestingTerm
    ) external returns ( uint tokenId, uint sOHMValue ) {
        // interface the new available token index
        Receipt storage receipt = tokenToReceipt [ tokenCount ];
        // transfer users OHM to contract
        IERC20( address( wsOHM ) ).safeTransferFrom( msg.sender, address(this), amount );
        // set token id for return before its updated
        tokenId = tokenCount;
        // log receipt info
        receipt.depositor = depositor;
        receipt.amount = amount;
        receipt.vestingTerm = vestingTerm;
        // get sOHM value of depositors wsOHM for return
        sOHMValue = wsOHM.sOHMValue( amount );
        // store amount to be paid back to depositor after vestingTerm
        receipt.inititialStakedOhmValue = sOHMValue;        
    }

    function redeem( 
        uint _tokenId
    ) external returns ( uint payout, bool fullyVested ) {
        // make sure token exists
        require( _exists( _tokenId ) );
        // interface the tokens Receipt
        Receipt storage receipt = tokenToReceipt [ _tokenId ];
        // make sure caller owns the token or is the orginal depositor
        require( ownerOf[ _tokenId ] == msg.sender || msg.sender == receipt.depositor, "You're not the owner");
        // get the current value of the minters deposited wsOHM denominated in sOHM
        uint currentValueInSOHM = wsOHM.sOHMValue( receipt.amount );
        // make sure there's sOHM to be claimed
        require( receipt.inititialStakedOhmValue < currentValueInSOHM,  "nothing to claim");
        // calculate payout in sOHM
        uint payoutInSOHM = currentValueInSOHM - receipt.inititialStakedOhmValue;
        // calculate payout in wsOHM
        payout = wsOHM.wOHMValue( payoutInSOHM );
        // subtract the wsOHM that was paid out from the minters deposit amount 
        receipt.amount -= payout;
        // make sure depositor still has at least their original deposit denominated in staked ohm
        require( receipt.amount >= receipt.inititialStakedOhmValue, "math error" );
        // transfer token holder their payout
        IERC20( address( wsOHM ) ).safeTransfer( ownerOf[ _tokenId ], payout);
        // if vesting is compete 
        if ( receipt.vestingTerm >= block.timestamp ) {
            // burn the token
            _burn( _tokenId );
            // return fully vested
            fullyVested = true;
            // return a payout of 0 since vesting is over
            payout = 0;
            // transfer depositor their wsOHM back
            IERC20( address( wsOHM ) ).safeTransfer( receipt.depositor, receipt.amount);
        } 
    }


    function bid(
        uint _tokenId,
        address _principal,
        uint _amount,
        uint _deadline
    ) external {
        // make sure token exists
        require( _exists( _tokenId ), "Bond doesn't exist" );
        // interface tokens bids array
        Bid[] storage bids = tokenBids[ _tokenId ];
        // push bid to storage
        bids.push(
            Bid({
                bidder: msg.sender,
                principal: _principal,
                amount: _amount,
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
        // make sure token exists
        require( _exists( _tokenId ), "Token doesn't exist" );
        // make sure caller is owner of the token
        require( msg.sender == ownerOf[ _tokenId ], "You're not the owner");
        // interface tokens array of bids
        Bid[] storage bids = tokenBids[ _tokenId ];
        // interface bid thats being accepted
        Bid storage acceptedBid = bids[ _bidId ];
        // ensure the deadline isn't over
        require( acceptedBid.deadline >= block.timestamp, "Bid's invalid");
        // transfer bid payment to tokens owner
        IERC20( acceptedBid.principal ).safeTransfer( ownerOf[ _tokenId ], acceptedBid.amount );
        // transfer token to its new owner
        safeTransferFrom(ownerOf[ _tokenId ], acceptedBid.bidder, _tokenId);
    }

    function cancelBid(
        uint _tokenId,
        uint _bidId
    ) external {
        // make sure token exists
        require( _exists( _tokenId ), "Token doesn't exist" );
        // make sure caller is owner of the token
        require( msg.sender == ownerOf[ _tokenId ], "You're not the owner");
        // interface tokens array of bids
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
