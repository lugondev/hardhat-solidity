// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./ERC721.sol";

contract OwnableDelegateProxy {}

contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}

pragma experimental ABIEncoderV2;

contract SquareFactory is Ownable {
    using SafeMath for uint256;
    uint256 public _currentTokenId;
    address public _manager;

    mapping(uint256 => uint256) internal _sTokenPositionsSquare;
    mapping(uint256 => bool) internal _existPositionsSquare;

    modifier onlyManager {
        require(msg.sender == _manager);
        _;
    }

    constructor() public {
        _manager = msg.sender;
    }

    struct SPropAd {
        string adText;
        string adUrl;
        string imgIpfs;
    }

    event UpdateSquareAd(uint256 indexed tokenId, SPropAd prop);

    mapping(uint256 => SPropAd) internal _sProps;
    mapping(uint256 => bool) internal _sForRent;

    function random() public view returns (uint256) {
        uint256 randomnumber =
            uint256(
                keccak256(abi.encodePacked(now, msg.sender, _currentTokenId))
            ) % 999;
        randomnumber = randomnumber.add(1);
        return randomnumber;
    }

    function updateAd(
        uint256 tokenId,
        string memory adText,
        string memory adUrl,
        string memory imgIpfs
    ) public virtual {
        SPropAd memory sProp =
            SPropAd({adText: adText, adUrl: adUrl, imgIpfs: imgIpfs});
        _sProps[tokenId] = sProp;
        emit UpdateSquareAd(tokenId, sProp);
    }

    function updateManager(address newManager) public onlyOwner {
        _manager = newManager;
    }
}

contract TokenNFT is ERC721, SquareFactory {
    using SafeMath for uint256;

    address proxyRegistryAddress;
    event MintSquare(uint256 indexed tokenId, uint256 position);

    enum Rarity {TOP_NOTCH, LEGENDARY, EPIC, RARE, NORMAL_RARE, COMMON}

    uint256 public constant SIZE_SIDE_SQUARE = 100;
    uint256 public constant MAX_SQUARES = SIZE_SIDE_SQUARE**2;

    constructor(string memory _name, string memory _symbol)
        public
        ERC721(_name, _symbol)
    {}

    modifier validPositionSquare(uint256 positionSquare) {
        require(
            positionSquare > 0 && positionSquare <= MAX_SQUARES,
            "Invalid position"
        );
        _;
    }

    function getSquareRarity(uint256 square)
        public
        pure
        validPositionSquare(square)
        returns (Rarity)
    {
        uint256 y = 0;
        uint256 x = 0;

        if (square < 100) {
            x = square;
        } else {
            y = square.div(100);
            x = square.mod(100);
        }
        return getSquareRarityCoordinates(x, y);
    }

    function getSquareRarityCoordinates(uint256 x, uint256 y)
        public
        pure
        validPositionSquare(y.mul(100).add(x))
        returns (Rarity)
    {
        bool isSquare90Index = isIndexInSquare(x, y, Rarity.NORMAL_RARE); //90x90
        bool isSquare70Index = isIndexInSquare(x, y, Rarity.RARE); //70x70
        bool isSquare50Index = isIndexInSquare(x, y, Rarity.EPIC); //50x50
        bool isSquare30Index = isIndexInSquare(x, y, Rarity.LEGENDARY); //30x30
        bool isCenterIndex = isIndexInSquare(x, y, Rarity.TOP_NOTCH); // 12x12

        if (isCenterIndex) return Rarity.TOP_NOTCH;
        if (isSquare30Index) return Rarity.LEGENDARY;
        if (isSquare50Index) return Rarity.EPIC;
        if (isSquare70Index) return Rarity.RARE;
        if (isSquare90Index) return Rarity.NORMAL_RARE;
        return Rarity.COMMON;
    }

    function isIndexInSquare(
        uint256 x,
        uint256 y,
        Rarity rarity
    ) internal pure validPositionSquare(y.mul(100).add(x)) returns (bool) {
        uint256 start = 0;
        uint256 end = 0;
        if (rarity == Rarity.TOP_NOTCH) {
            start = 43;
            end = 55;
        }
        if (rarity == Rarity.LEGENDARY) {
            start = 34;
            end = 64;
        }
        if (rarity == Rarity.EPIC) {
            start = 24;
            end = 74;
        }
        if (rarity == Rarity.RARE) {
            start = 14;
            end = 84;
        }
        if (rarity == Rarity.NORMAL_RARE) {
            start = 7;
            end = 91;
        }

        if (start == 0) return true;

        uint256 size = end - start;
        return
            x > start &&
            x <= end &&
            y > start &&
            y <= end &&
            !(x > start + size &&
                x <= end - size &&
                y > start + size &&
                y <= end - size);
    }

    function _mint(address to, uint256 tokenId) internal override(ERC721) {
        super._mint(to, tokenId);

        _incrementTokenId();
    }

    function mint(address to, uint256 positionSquare)
        public
        validPositionSquare(positionSquare)
        onlyManager
    {
        uint256 nextTokenId = _getNextTokenId();
        require(_sTokenPositionsSquare[nextTokenId] == 0, "Already minted");
        require(!isExistSquare(positionSquare), "Already minted");

        _mint(to, nextTokenId);

        emit MintSquare(nextTokenId, positionSquare);
        _sTokenPositionsSquare[nextTokenId] = positionSquare;
        _existPositionsSquare[positionSquare] = true;
    }

    function multiMint(address to, uint256[] memory positions)
        public
        onlyManager
    {
        require(positions.length > 1, "Must multiple mint");
        for (uint256 index = 0; index < positions.length; index++) {
            mint(to, positions[index]);
        }
    }

    function updateAd(
        uint256 tokenId,
        string memory adText,
        string memory adUrl,
        string memory imgIpfs
    ) public override {
        require(
            tokenId > 0 && tokenId <= _currentTokenId,
            "Token is not exists."
        );
        require(
            ownerOf(tokenId) == msg.sender,
            "require ownerOf token for this action"
        );
        super.updateAd(tokenId, adText, adUrl, imgIpfs);
    }

    /**
     * @dev calculates the next token ID based on value of _currentTokenId
     * @return uint256 for the next token ID
     */
    function _getNextTokenId() private view returns (uint256) {
        return _currentTokenId.add(1);
    }

    /**
     * @dev increments the value of _currentTokenId
     */
    function _incrementTokenId() private {
        _currentTokenId++;
    }

    /**
     * Override isApprovedForAll to whitelist user's proxy accounts.
     */
    function isApprovedForAll(address owner, address operator)
        public
        view
        override
        returns (bool)
    {
        // Whitelist proxy contract for easy trading.
        // ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
        // if (address(proxyRegistry.proxies(owner)) == operator) {
        //     return true;
        // }

        return super.isApprovedForAll(owner, operator);
    }

    function updateProxyRegistryAddress(address _proxyRegistryAddress)
        public
        onlyOwner
    {
        proxyRegistryAddress = _proxyRegistryAddress;
    }

    function isExistSquare(uint256 positionSquare)
        public
        view
        returns (bool isExist)
    {
        isExist = _existPositionsSquare[positionSquare];
    }

    function isRented(uint256 tokenId) public view returns (bool) {
        return _sForRent[tokenId];
    }

    function getPositionSquareToken(uint256 tokenId)
        public
        view
        returns (uint256 position)
    {
        position = _sTokenPositionsSquare[tokenId];
    }

    function getAdData(uint256 tokenId)
        external
        view
        returns (
            string memory adText,
            string memory adUrl,
            string memory imgIpfs
        )
    {
        SPropAd memory ad = _sProps[tokenId];
        adText = ad.adText;
        adUrl = ad.adUrl;
        imgIpfs = ad.imgIpfs;
    }

    function getSquareData(uint256 tokenId)
        external
        view
        returns (
            uint256 position,
            address owner,
            SPropAd memory ad
        )
    {
        position = _sTokenPositionsSquare[tokenId];
        owner = ownerOf(tokenId);
        ad = _sProps[tokenId];
    }
}
