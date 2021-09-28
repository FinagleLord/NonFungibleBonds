// SPDX-License-Identifier: WTFPL
pragma solidity ^0.8.0;

interface IOwnable {
  function policy() external view returns (address);
  function renounceManagement() external;
  function pushManagement( address newOwner_ ) external;
  function pullManagement() external;
}

contract Ownable is IOwnable {

    address internal _owner;
    address internal _newOwner;

    event OwnershipPushed(address indexed previousOwner, address indexed newOwner);
    event OwnershipPulled(address indexed previousOwner, address indexed newOwner);

    constructor () {
        _owner = msg.sender;
        emit OwnershipPushed( address(0), _owner );
    }

    function policy() public view virtual override returns (address) {
        return _owner;
    }

    modifier onlyPolicy() {
        require( _owner == msg.sender, "Ownable: caller is not the owner" );
        _;
    }

    function renounceManagement() public virtual override onlyPolicy() {
        emit OwnershipPushed( _owner, address(0) );
        _owner = address(0);
    }

    function pushManagement( address newOwner_ ) public virtual override onlyPolicy() {
        require( newOwner_ != address(0), "Ownable: new owner is the zero address");
        emit OwnershipPushed( _owner, newOwner_ );
        _newOwner = newOwner_;
    }
    
    function pullManagement() public virtual override {
        require( msg.sender == _newOwner, "Ownable: must be new owner to pull");
        emit OwnershipPulled( _owner, _newOwner );
        _owner = _newOwner;
    }
}

interface IERC721 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address operator);
    function setApprovalForAll(address operator, bool _approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
}

interface IERC721Metadata is IERC721 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

abstract contract ERC165 is IERC165 {
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}

library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}


interface IERC20 {
  function totalSupply() external view returns (uint256);
  function balanceOf(address account) external view returns (uint256);
  function transfer(address recipient, uint256 amount) external returns (bool);
  function allowance(address owner, address spender) external view returns (uint256);
  function approve(address spender, uint256 amount) external returns (bool);
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

/// @notice from Rari Lab's solmate repo
library SafeERC20 {
    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );

        require(success && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FROM_FAILED");
    }

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FAILED");
    }

    function safeApprove(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.approve.selector, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "APPROVE_FAILED");
    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "ETH_TRANSFER_FAILED");
    }
}

interface IUniqueBondDepository {
    function deposit( uint _amount, uint _maxPrice, address _depositor) external returns ( uint payout, uint bondID );
    function redeem( uint _bondId, address _to ) external returns ( uint payout, bool fullyVested );
}





contract NonFungibleToken is ERC165, IERC721, IERC721Metadata {

    using Address for address;
    using Strings for uint256;

    /////////////// storage ///////////////


    string public name;

    string public symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) public ownerOf;

    // Mapping owner address to token count
    mapping(address => uint256) public balanceOf;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;


    /////////////// construction ///////////////


    constructor(
        string memory name_, 
        string memory symbol_
    ) {
        name = name_;
        symbol = symbol_;
    }

    /////////////// nft logic  ///////////////


    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ownerOf[ tokenId ];
        require(to != owner, "ERC721: approval to current owner");
        require(msg.sender == owner || isApprovedForAll(owner, msg.sender),"ERC721: caller is not owner or approved for all");
        _approve(to, tokenId);
    }

    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(operator != msg.sender, "ERC721: approve to caller");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return ownerOf[tokenId] != address(0);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ownerOf[ tokenId ];
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(_checkOnERC721Received(address(0), to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");
        _beforeTokenTransfer(address(0), to, tokenId);
        balanceOf[to] += 1;
        ownerOf[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
    }

    function _burn(uint256 tokenId) internal virtual {
        address owner = ownerOf[ tokenId ];
        _beforeTokenTransfer(owner, address(0), tokenId);
        // Clear approvals
        _approve(address(0), tokenId);
        balanceOf[owner] -= 1;
        delete ownerOf[tokenId];
        emit Transfer(owner, address(0), tokenId);
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ownerOf[ tokenId ] == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");
        _beforeTokenTransfer(from, to, tokenId);
        // Clear approvals from the previous owner
        _approve(address(0), tokenId);
        balanceOf[from] -= 1;
        balanceOf[to] += 1;
        ownerOf[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(  ownerOf[ tokenId ], to, tokenId);
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}

interface IwsOHM {
    function unwrap( uint _amount ) external returns ( uint );
    function wrap( uint _amount ) external returns ( uint );
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function sOHMValue( uint _amount ) external view returns ( uint );
    function wOHMValue( uint _amount ) external view returns ( uint );
}



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