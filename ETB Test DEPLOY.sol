// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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

abstract contract Context {
    function _msgSender() internal view virtual returns (address) { return msg.sender; }
}

abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor() { _transferOwnership(_msgSender()); }
    function owner() public view returns (address) { return _owner; }
    modifier onlyOwner() { require(owner() == _msgSender(), "Ownable: caller is not owner"); _; }
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: zero address");
        _transferOwnership(newOwner);
    }
    function _transferOwnership(address newOwner) internal {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract ReentrancyGuard {
    uint256 private _status;
    constructor() { _status = 1; }
    modifier nonReentrant() {
        require(_status != 2, "Reentrant call");
        _status = 2;
        _;
        _status = 1;
    }
}

contract ERC20 is Context, IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) { _name = name_; _symbol = symbol_; }
    function name() public view returns (string memory) { return _name; }
    function symbol() public view returns (string memory) { return _symbol; }
    function decimals() public pure returns (uint8) { return 18; }
    function totalSupply() public view override returns (uint256) { return _totalSupply; }
    function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }
    function transfer(address recipient, uint256 amount) public override returns (bool) { _transfer(_msgSender(), recipient, amount); return true; }
    function allowance(address owner, address spender) public view override returns (uint256) { return _allowances[owner][spender]; }
    function approve(address spender, uint256 amount) public override returns (bool) { _approve(_msgSender(), spender, amount); return true; }
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "Allowance exceeded");
        unchecked { _approve(sender, _msgSender(), currentAllowance - amount); }
        return true;
    }
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0) && recipient != address(0), "Zero address");
        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "Insufficient balance");
        unchecked { _balances[sender] = senderBalance - amount; }
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "Mint zero address");
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "Burn zero address");
        uint256 bal = _balances[account];
        require(bal >= amount, "Burn exceeds balance");
        unchecked { _balances[account] = bal - amount; }
        _totalSupply -= amount;
        emit Transfer(address(0), account, amount);
    }
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0) && spender != address(0), "Approve zero");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}

contract ETBToken is ERC20, Ownable, ReentrancyGuard {
    uint256 public constant MAX_SUPPLY = 21_000_000 * 10**18;
    uint256 public initialBlockReward = 2 * 10**18; // 2 ETB

    uint256 public minContribution = 0.00001 ether;
    uint256 public maxContribution = 10 ether;

    struct Participant {
        uint256 contributedETH;
        bool claimed;
    }

    mapping(uint256 => mapping(address => Participant)) public blockParticipants;
    mapping(uint256 => uint256) public blockTotalETH;
    mapping(address => uint256[]) public userBlocks; // user-specific block list

    constructor() ERC20("ETB Token", "ETB") {
        _mint(msg.sender, 105_000 * 10**18); // Premint
    }

    receive() external payable nonReentrant {
        require(msg.value >= minContribution, "Below minimum contribution");

        uint256 blockNumber = block.number;
        Participant storage p = blockParticipants[blockNumber][msg.sender];
        require(p.contributedETH + msg.value <= maxContribution, "Exceeds max contribution per block");

        if(p.contributedETH == 0){
            userBlocks[msg.sender].push(blockNumber); // Add block to user's list first time
        }

        p.contributedETH += msg.value;
        blockTotalETH[blockNumber] += msg.value;
    }

    // ===============================
    // Stage-based reward system (21 stages)
    // ===============================
function getCurrentBlockReward() public view returns (uint256) {
    uint256 supply = totalSupply();

    if(supply < 10_500_000 * 10**18) return 2 * 10**18;
    else if(supply < 15_750_000 * 10**18) return 1 * 10**18;
    else if(supply < 18_375_000 * 10**18) return 5e17;          // 0.5 ETB
    else if(supply < 19_687_500 * 10**18) return 25e16;         // 0.25 ETB
    else if(supply < 20_343_750 * 10**18) return 125e15;        // 0.125 ETB
    else if(supply < 20_671_875 * 10**18) return 62500000000000000; // 0.0625 ETB
    else if(supply < 20_835_937 * 10**18) return 31250000000000000; // 0.03125 ETB
    else if(supply < 20_917_968 * 10**18) return 15625000000000000; // 0.015625 ETB
    else if(supply < 20_958_984 * 10**18) return 7812500000000000;  // 0.0078125 ETB
    else if(supply < 20_979_492 * 10**18) return 3906250000000000;  // 0.00390625 ETB
    else if(supply < 20_989_746 * 10**18) return 1953125000000000;  // 0.001953125 ETB
    else if(supply < 20_994_873 * 10**18) return 976562500000000;   // 0.0009765625 ETB
    else if(supply < 20_997_436 * 10**18) return 488281250000000;   // 0.00048828125 ETB
    else if(supply < 20_998_718 * 10**18) return 244140625000000;   // 0.000244140625 ETB
    else if(supply < 20_999_359 * 10**18) return 122070312500000;   // 0.0001220703125 ETB
    else if(supply < 20_999_679 * 10**18) return 61035156250000;    // 0.00006103515625 ETB
    else if(supply < 20_999_839 * 10**18) return 30517578125000;    // 0.000030517578125 ETB
    else if(supply < 20_999_919 * 10**18) return 15258789062500;    // 0.0000152587890625 ETB
    else if(supply < 20_999_959 * 10**18) return 7629394531250;     // 0.00000762939453125 ETB
    else if(supply < 20_999_979 * 10**18) return 3814697265625;     // 0.000003814697265625 ETB
    else return 1907348632812;                                      // 0.0000019073486328125 ETB
}



    function claimPendingRewards() external nonReentrant {
        uint256 totalReward = 0;
        uint256[] storage blocks = userBlocks[msg.sender];
        for (uint256 i = 0; i < blocks.length; i++) {
            uint256 blk = blocks[i];
            Participant storage p = blockParticipants[blk][msg.sender];
            if (!p.claimed && p.contributedETH > 0 && blockTotalETH[blk] > 0) {
                uint256 reward = (getCurrentBlockReward() * p.contributedETH) / blockTotalETH[blk];
                totalReward += reward;
                p.claimed = true;
            }
        }

        require(totalReward > 0, "No rewards to claim");
        require(totalSupply() + totalReward <= MAX_SUPPLY, "Exceeds max supply");

        _mint(msg.sender, totalReward);
    }

    function emergencyWithdrawETH(address payable to, uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Not enough ETH");
        to.transfer(amount);
    }

    function setContributionLimits(uint256 minAmount, uint256 maxAmount) external onlyOwner {
        minContribution = minAmount;
        maxContribution = maxAmount;
    }
}
