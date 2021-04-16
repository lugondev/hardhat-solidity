pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract MillionDotToken is ERC20Burnable, Ownable {
    using SafeMath for uint256;

    uint256 public maxSupply;
    mapping(address => bool) minters;

    constructor(
        string memory name,
        string memory symbol,
        uint256 _initialSupply,
        uint256 _maxSupply,
        address owner
    ) ERC20(name, symbol) {
        maxSupply = _maxSupply;
        _mint(owner, _initialSupply);
    }

    modifier onlyMinter(address minter) {
        require(minters[minter], "caller is not the minter");
        _;
    }

    function updateMinter(address minter, bool status) external onlyOwner {
        require(minters[minter] != status);

        minters[minter] = status;
    }

    function mintable() public view returns (uint256) {
        return maxSupply.sub(totalSupply());
    }

    function mint(address recipient, uint256 amount)
        external
        onlyMinter(_msgSender())
    {
        require(recipient != address(0), "0x is not accepted here");
        require(amount > 0, "not accept 0 value");
        require(totalSupply().add(amount) <= maxSupply, "Over maxSupply");

        _mint(recipient, amount);
    }
}
