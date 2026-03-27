pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
    // ------------------------------------------ //
    // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
    // ------------------------------------------ //
    using SafeMath for uint256;
    uint256 public totalSupply;
    uint256 public decimals = 18;
    string public name = "Test token";
    string public symbol = "TEST";
    mapping(address => uint256) public balanceOf;
    // ------------------------------------------ //
    // ----- END: DO NOT EDIT THIS SECTION ------ //
    // ------------------------------------------ //

    mapping(address => mapping(address => uint256)) private _allowances;
    address[] private _holders;
    //1- based indexing
    mapping(address => uint256) private _holderIndex;
    mapping(address => uint256) private _withdrawableDividends;

    // IERC20

    function allowance(
        address owner,
        address spender
    ) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function transfer(
        address to,
        uint256 value
    ) external override returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(
        address spender,
        uint256 value
    ) external override returns (bool) {
        require(value > 0);
        _allowances[msg.sender][spender] = value;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override returns (bool) {
        require(value > 0);
        require(_allowances[from][msg.sender] >= value);
        _allowances[from][msg.sender] = _allowances[from][msg.sender].sub(
            value
        );
        _transfer(from, to, value);
        return true;
    }

    // IMintableToken

    function mint() external payable override {
        require(msg.value > 0, "no eth supplied");

        balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
        totalSupply = totalSupply.add(msg.value);

        _syncHolder(msg.sender);
    }

    function burn(address payable dest) external override {
        uint256 amount = balanceOf[msg.sender];
        require(amount > 0, "nothing to burn");

        balanceOf[msg.sender] = 0;
        totalSupply = totalSupply.sub(amount);

        _syncHolder(msg.sender);

        (bool ok, ) = dest.call{value: amount}("");
        require(ok, "eth transfer failed");
    }

    // IDividends

    function getNumTokenHolders() external view override returns (uint256) {
        return _holders.length;
    }

    function getTokenHolder(
        uint256 index
    ) external view override returns (address) {
        if (index == 0 || index > _holders.length) {
            return address(0);
        }
        return _holders[index - 1];
    }

    function recordDividend() external payable override {
        require(msg.value > 0, "no dividend eth");
        require(totalSupply > 0, "no token supply");

        for (uint256 i = 0; i < _holders.length; i += 1) {
            address holder = _holders[i];
            uint256 payout = msg.value.mul(balanceOf[holder]).div(totalSupply);
            _withdrawableDividends[holder] = _withdrawableDividends[holder].add(
                payout
            );
        }
    }

    function getWithdrawableDividend(
        address payee
    ) external view override returns (uint256) {
        return _withdrawableDividends[payee];
    }

    function withdrawDividend(address payable dest) external override {
        uint256 amount = _withdrawableDividends[msg.sender];
        _withdrawableDividends[msg.sender] = 0;

        if (amount == 0) {
            return;
        }

        (bool ok, ) = dest.call{value: amount}("");
        require(ok, "eth transfer failed");
    }

    // helper methods
    function _transfer(address from, address to, uint256 value) internal {
        require(balanceOf[from] >= value);
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);

        _syncHolder(from);
        _syncHolder(to);
    }

    function _syncHolder(address account) internal {
        if (balanceOf[account] > 0) {
            if (_holderIndex[account] == 0) {
                _holders.push(account);
                _holderIndex[account] = _holders.length;
            }
            return;
        }

        uint256 idxPlusOne = _holderIndex[account];
        if (idxPlusOne == 0) {
            return;
        }

        uint256 idx = idxPlusOne - 1;
        uint256 lastIdx = _holders.length - 1;

        if (idx != lastIdx) {
            address moved = _holders[lastIdx];
            _holders[idx] = moved;
            _holderIndex[moved] = idx + 1;
        }

        _holders.pop();
        _holderIndex[account] = 0;
    }
}
