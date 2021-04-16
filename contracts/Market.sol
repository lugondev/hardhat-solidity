pragma solidity ^0.6.0;

pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./Governance.sol";

interface MintDotTokenErc20 {
    function mintable() external view returns (uint256);

    function mint(address recipient, uint256 amount) external;
}

contract NFTMarket is IERC721Receiver, Governance, Context {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IERC20 public _mdotToken = IERC20(0);

    struct SalesObject {
        uint256 id;
        uint256 tokenId;
        address seller;
        IERC721 nft;
        IERC20 paymentToken;
        address buyer;
        uint256 startTime;
        uint256 durationTime;
        uint256 price;
        uint8 status;
    }

    struct AuctionsObject {
        uint256 id;
        uint256 tokenId;
        address seller;
        IERC721 nft;
        IERC20 paymentToken;
        address buyer;
        uint256 startTime;
        uint256 durationTime;
        uint256 maxPrice;
        uint256 minPrice;
        uint256 finalPrice;
        uint8 status;
    }

    uint256 private _salesAmount = 0;

    SalesObject[] _salesObjects;
    AuctionsObject[] _auctionsObjects;

    uint256 public _minDurationTime = 5 minutes;

    mapping(address => bool) public _seller;
    mapping(address => bool) public _verifySeller;
    mapping(address => bool) public _supportNft;
    mapping(address => mapping(uint256 => uint256)) public _indexTokenNft;
    mapping(address => bool) public _supportTokenPayment;
    bool public _isStartUserSales;

    bool public _isRewardSeller = false;
    bool public _isRewardBuyer = false;

    uint256 public _sellerReward = 1e15;
    uint256 public _buyerReward = 1e15;

    uint256 public _tipsFeeRate = 20;
    uint256 public _baseRate = 1000;
    address public _tipsFeeWallet;

    event Sales(
        uint256 indexed id,
        uint256 tokenId,
        address buyer,
        uint256 finalPrice,
        uint256 tipsFee
    );

    event NewSales(
        uint256 indexed id,
        uint256 tokenId,
        address seller,
        address nft,
        address paymentToken,
        address buyer,
        uint256 startTime,
        uint256 price
    );

    event NewAuction(
        uint256 indexed id,
        uint256 tokenId,
        address seller,
        address nft,
        address paymentToken,
        address buyer,
        uint256 startTime,
        uint256 durationTime,
        uint256 maxPrice,
        uint256 minPrice
    );

    event CancelSales(uint256 indexed id, uint256 tokenId);

    event NFTReceived(
        address operator,
        address from,
        uint256 tokenId,
        bytes data
    );

    constructor() public {
        _tipsFeeWallet = _msgSender();
    }

    modifier validAddress(address addr) {
        require(addr != address(0), "require not 0x");
        _;
    }

    modifier validAddressNFT(address addr) {
        require(addr != address(0), "require not 0x");
        require(_supportNft[addr], "not support address");
        _;
    }

    modifier checkIndexSale(uint256 index) {
        require(index <= _salesObjects.length, "overflow");
        _;
    }

    modifier checkTime(uint256 index) {
        require(index <= _salesObjects.length, "overflow");
        SalesObject storage obj = _salesObjects[index];
        require(obj.startTime <= block.timestamp, "!open");
        _;
    }

    modifier mustNotSellingOut(uint256 index) {
        require(index <= _salesObjects.length, "overflow");
        SalesObject storage obj = _salesObjects[index];
        require(obj.buyer == address(0) && obj.status == 0, "selling out");
        _;
    }

    modifier onlySalesOwner(uint256 index) {
        require(index <= _salesObjects.length, "overflow");
        SalesObject storage obj = _salesObjects[index];
        require(
            obj.seller == _msgSender() || _msgSender() == _governance,
            "author & governance"
        );
        _;
    }

    function seize(IERC20 asset) external returns (uint256 balance) {
        balance = asset.balanceOf(address(this));
        asset.safeTransfer(_governance, balance);
    }

    function setSellerReward(uint256 reward) public onlyGovernance {
        _sellerReward = reward;
    }

    function setBuyerReward(uint256 reward) public onlyGovernance {
        _sellerReward = reward;
    }

    function supportNft(address nft, bool status)
        public
        onlyGovernance
        validAddress(nft)
    {
        require(_supportNft[nft] != status);

        _supportNft[nft] = status;
    }

    function supportPaymentToken(address paymentToken, bool status)
        public
        onlyGovernance
        validAddress(paymentToken)
    {
        require(_supportTokenPayment[paymentToken] != status);

        _supportTokenPayment[paymentToken] = status;
    }

    function updateSeller(address seller, bool status)
        public
        onlyGovernance
        validAddress(seller)
    {
        require(_seller[seller] != status);

        _seller[seller] = status;
    }

    function verifySeller(address seller, bool status)
        public
        onlyGovernance
        validAddress(seller)
    {
        require(_verifySeller[seller] != status);

        _verifySeller[seller] = status;
    }

    function setIsStartUserSales(bool isStartUserSales) public onlyGovernance {
        _isStartUserSales = isStartUserSales;
    }

    function setIsRewardSeller(bool isRewardSeller) public onlyGovernance {
        _isRewardSeller = isRewardSeller;
    }

    function setIsRewardBuyer(bool isRewardBuyer) public onlyGovernance {
        _isRewardBuyer = isRewardBuyer;
    }

    function setMinDurationTime(uint256 durationTime) public onlyGovernance {
        _minDurationTime = durationTime;
    }

    function setTipsFeeWallet(address wallet) public onlyGovernance {
        _tipsFeeWallet = wallet;
    }

    function getSalesEndTime(uint256 index)
        external
        view
        checkIndexSale(index)
        returns (uint256)
    {
        SalesObject storage obj = _salesObjects[index];
        return obj.startTime.add(obj.durationTime);
    }

    function getSales(uint256 index)
        external
        view
        checkIndexSale(index)
        returns (SalesObject memory)
    {
        return _salesObjects[index];
    }

    function getSalesPrice(uint256 index) public view returns (uint256) {
        if (index > _salesObjects.length || index == 0) {
            return 0;
        }
        SalesObject storage obj = _salesObjects[index];
        return obj.price;
    }

    function getPrice(address nft, uint256 tokenId)
        public
        view
        returns (uint256 price)
    {
        price = getSalesPrice(_indexTokenNft[nft][tokenId]);
    }

    function setMdotTokenAddress(address addr)
        external
        onlyGovernance
        validAddress(addr)
    {
        _mdotToken = IERC20(addr);
    }

    function setBaseRate(uint256 rate) external onlyGovernance {
        _baseRate = rate;
    }

    function setTipsFeeRate(uint256 rate) external onlyGovernance {
        _tipsFeeRate = rate;
    }

    function isVerifySeller(uint256 index)
        public
        view
        checkIndexSale(index)
        returns (bool)
    {
        SalesObject storage obj = _salesObjects[index];
        return _verifySeller[obj.seller];
    }

    function cancelSales(uint256 index)
        external
        checkIndexSale(index)
        onlySalesOwner(index)
        mustNotSellingOut(index)
    {
        SalesObject storage obj = _salesObjects[index];
        obj.status = 2;
        obj.nft.safeTransferFrom(address(this), obj.seller, obj.tokenId);

        emit CancelSales(index, obj.tokenId);
    }

    function createSale(
        uint256 tokenId,
        uint256 price,
        uint256 startTime,
        address nft,
        address paymentToken
    ) external validAddressNFT(nft) returns (uint256) {
        require(_supportTokenPayment[paymentToken], "Invalid payment token");

        require(tokenId != 0, "Invalid NFT item");
        startTime = startTime == 0 ? block.timestamp.add(5 minutes) : startTime;

        require(
            _isStartUserSales || _seller[_msgSender()] == true,
            "cannot sales"
        );

        IERC721(nft).safeTransferFrom(_msgSender(), address(this), tokenId);

        _salesAmount++;
        SalesObject memory obj;

        obj.id = _salesAmount;
        obj.tokenId = tokenId;
        obj.seller = _msgSender();
        obj.nft = IERC721(nft);
        obj.paymentToken = IERC20(paymentToken);
        obj.buyer = address(0);
        obj.startTime = startTime;
        obj.price = price;
        obj.status = 0;

        if (_salesObjects.length == 0) {
            SalesObject memory zeroObj;
            zeroObj.tokenId = 0;
            zeroObj.seller = address(0);
            zeroObj.nft = IERC721(0x0);
            zeroObj.paymentToken = IERC20(0x0);
            zeroObj.buyer = address(0);
            zeroObj.startTime = 0;
            zeroObj.price = 0;
            zeroObj.status = 2;
            _salesObjects.push(zeroObj);
        }

        _salesObjects.push(obj);

        if (_isRewardSeller || _verifySeller[_msgSender()]) {
            MintDotTokenErc20 mintDot = MintDotTokenErc20(address(_mdotToken));
            if (mintDot.mintable() >= _sellerReward)
                mintDot.mint(_msgSender(), _sellerReward);
        }

        emit NewSales(
            obj.id,
            tokenId,
            _msgSender(),
            nft,
            paymentToken,
            address(0),
            startTime,
            obj.price
        );

        _indexTokenNft[address(nft)][tokenId] = _salesAmount;

        return _salesAmount;
    }

    // function createAuction(
    //     uint256 tokenId,
    //     uint256 minPrice,
    //     uint256 maxPrice,
    //     uint256 startTime,
    //     uint256 durationTime,
    //     address nft,
    //     address paymentToken
    // ) external validAddressNFT(nft) returns (uint256) {
    //     require(_supportTokenPayment[paymentToken], "Invalid payment token");

    //     require(tokenId != 0, "Invalid NFT item");
    //     startTime = startTime == 0 ? block.timestamp.add(5 minutes) : startTime;

    //     require(
    //         startTime.add(durationTime) > block.timestamp,
    //         "invalid start time"
    //     );

    //     require(durationTime >= _minDurationTime, "invalid duration");
    //     require(minPrice > 0, "Invalid min price");

    //     if (maxPrice == 0 || maxPrice < minPrice) {
    //         maxPrice = minPrice;
    //     }

    //     require(
    //         _isStartUserSales || _seller[_msgSender()] == true,
    //         "cannot sales"
    //     );

    //     IERC721(nft).safeTransferFrom(_msgSender(), address(this), tokenId);

    //     _salesAmount++;
    //     SalesObject memory obj;

    //     obj.id = _salesAmount;
    //     obj.tokenId = tokenId;
    //     obj.seller = _msgSender();
    //     obj.nft = IERC721(nft);
    //     obj.paymentToken = IERC20(paymentToken);
    //     obj.buyer = address(0);
    //     obj.startTime = startTime;
    //     obj.durationTime = durationTime;
    //     obj.maxPrice = maxPrice;
    //     obj.minPrice = minPrice;
    //     obj.finalPrice = 0;
    //     obj.status = 0;

    //     if (_salesObjects.length == 0) {
    //         SalesObject memory zeroObj;
    //         zeroObj.tokenId = 0;
    //         zeroObj.seller = address(0);
    //         zeroObj.nft = IERC721(0x0);
    //         zeroObj.paymentToken = IERC20(0x0);
    //         zeroObj.buyer = address(0);
    //         zeroObj.startTime = 0;
    //         zeroObj.durationTime = 0;
    //         zeroObj.maxPrice = 0;
    //         zeroObj.minPrice = 0;
    //         zeroObj.finalPrice = 0;
    //         zeroObj.status = 2;
    //         _salesObjects.push(zeroObj);
    //     }

    //     _salesObjects.push(obj);

    //     if (_isRewardSeller || _verifySeller[_msgSender()]) {
    //         MintDotTokenErc20 mintDot = MintDotTokenErc20(address(_mdotToken));
    //         if (mintDot.mintable() >= _sellerReward)
    //             mintDot.mint(_msgSender(), _sellerReward);
    //     }

    //     emit NewSales(
    //         obj.id,
    //         tokenId,
    //         _msgSender(),
    //         nft,
    //         paymentToken,
    //         address(0),
    //         startTime,
    //         durationTime,
    //         obj.maxPrice,
    //         obj.minPrice
    //     );

    //     _indexTokenNft[address(nft)][tokenId] = _salesAmount;

    //     return _salesAmount;
    // }

    function buy(uint256 index)
        public
        mustNotSellingOut(index)
        checkTime(index)
    {
        SalesObject storage obj = _salesObjects[index];
        IERC20 paymentToken = IERC20(obj.paymentToken);
        uint256 price = this.getSalesPrice(index);

        uint256 tipsFee = price.mul(_tipsFeeRate).div(_baseRate);
        uint256 purchase = price.sub(tipsFee);

        paymentToken.transferFrom(_msgSender(), obj.seller, purchase);

        if (_isRewardBuyer || _verifySeller[obj.seller]) {
            MintDotTokenErc20 mintDot = MintDotTokenErc20(address(_mdotToken));
            if (mintDot.mintable() >= _buyerReward)
                mintDot.mint(_msgSender(), _buyerReward);
        }

        if (tipsFee > 0) {
            paymentToken.transferFrom(_msgSender(), obj.seller, purchase);
        }

        obj.nft.safeTransferFrom(address(this), _msgSender(), obj.tokenId);
        obj.buyer = _msgSender();
        obj.status = 1;

        // fire event
        emit Sales(index, obj.tokenId, _msgSender(), price, tipsFee);
    }

    function totalSales() public view returns (uint256) {
        return _salesAmount;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes memory data
    ) public override returns (bytes4) {
        //only receive the _nft staff
        if (address(this) != operator) {
            //invalid from nft
            return 0;
        }

        //success
        emit NFTReceived(operator, from, tokenId, data);
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }
}
