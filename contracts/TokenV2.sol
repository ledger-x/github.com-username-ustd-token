// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract TokenV2 is
    Initializable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    OwnableUpgradeable
{
    uint256 private constant _TOTAL_SUPPLY = 1_000_000_000 * 10 ** 18;

    address public v2Pool;
    address public v3Pool;

    bool public tradingEnabled;
    uint256 public tradeCooldown;
    uint256 public maxWallet;
    uint256 public maxTx;

    mapping(address => bool) public isBlacklisted;
    mapping(address => uint256) private lastTrade;

    event PoolsUpdated(address v2Pool, address v3Pool);
    event TradingEnabled(bool enabled);
    event BlacklistUpdated(address account, bool status);
    event TradeCooldownUpdated(uint256 cooldown);
    event MaxWalletUpdated(uint256 maxWallet);
    event MaxTxUpdated(uint256 maxTx);

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _initialOwner,
        address _v2Pool,
        address _v3Pool
    ) public initializer {
        __ERC20_init("", "");
        __ERC20Permit_init("");
        __Ownable_init(_initialOwner);

        v2Pool = _v2Pool;
        v3Pool = _v3Pool;

        tradeCooldown = 30;
        maxWallet = _TOTAL_SUPPLY / 50;  
        maxTx = _TOTAL_SUPPLY / 100;     
        tradingEnabled = false;

        _mint(_initialOwner, _TOTAL_SUPPLY);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (from != address(0) && to != address(0)) {
            _applyConstraints(from, to, amount);
        }
        super._update(from, to, amount);
    }

    function _applyConstraints(
        address from,
        address to,
        uint256 amount
    ) internal {
        require(!isBlacklisted[from] && !isBlacklisted[to], "Blacklisted");

        bool isPoolTx = (from == v2Pool || from == v3Pool ||
                         to == v2Pool || to == v3Pool);

        if (isPoolTx) {
            require(tradingEnabled, "Trading not enabled");

            address trader = (from == v2Pool || from == v3Pool) ? to : from;

            if (tradeCooldown > 0) {
                require(
                    block.timestamp >= lastTrade[trader] + tradeCooldown,
                    "Cooldown active"
                );
                lastTrade[trader] = block.timestamp;
            }

            require(amount <= maxTx, "Exceeds maxTx");

            if (to != v2Pool && to != v3Pool) {
                require(
                    balanceOf(to) + amount <= maxWallet,
                    "Exceeds maxWallet"
                );
            }
        }
    }

    function setPools(address _v2Pool, address _v3Pool) external onlyOwner {
        v2Pool = _v2Pool;
        v3Pool = _v3Pool;
        emit PoolsUpdated(_v2Pool, _v3Pool);
    }

    function setTradeCooldown(uint256 _seconds) external onlyOwner {
        require(_seconds <= 300, "Max 5 minutes");
        tradeCooldown = _seconds;
        emit TradeCooldownUpdated(_seconds);
    }

    function setBlacklist(address account, bool status) external onlyOwner {
        isBlacklisted[account] = status;
        emit BlacklistUpdated(account, status);
    }

    function setMaxWallet(uint256 _maxWallet) external onlyOwner {
        require(_maxWallet >= totalSupply() / 1000, "Too low");
        maxWallet = _maxWallet;
        emit MaxWalletUpdated(_maxWallet);
    }

    function setMaxTx(uint256 _maxTx) external onlyOwner {
        require(_maxTx >= totalSupply() / 1000, "Too low");
        maxTx = _maxTx;
        emit MaxTxUpdated(_maxTx);
    }

    function setTradingEnabled(bool _enabled) external onlyOwner {
        tradingEnabled = _enabled;
        emit TradingEnabled(_enabled);
    }
}
