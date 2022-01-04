// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./FCToken.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";




contract Stacking is ReentrancyGuard, Ownable
{
    using SafeMath for uint256;

    mapping(address => mapping(address => Stack))   private _lockedToken;
    mapping(address => address[])                   private myTokens;
    mapping(string => DataFeed)                     public  dataFeeds; // Mettre en private
    FCToken                                         private fcToken;
    uint256                                         private constant _INTEREST_PERIOD = 1 hours;
    uint256                                         private constant _INTEREST_VALUE = 25;
    uint256                                         private constant _RATE = 50;
    
    struct Stack
    {
        uint256 amount;
        uint256 lastAction;
        uint256 reward;
        address tokenAddress;
        bool    exist;
    }

    struct DataFeed
    {
        address dataAddress;
        bool    exist;
    }

    event locking(address stacker, address tokenAddress, uint256 amount);
    event unlocking(address stacker, address tokenAddress, uint256 amount);
    event newDataFeed(string name, address aggregator);
    event claiming(address stacker, uint256 amount);

    constructor()
    {
        fcToken = new FCToken();
    }

    function locked(address _tokenAddress, uint256 _amount) external
    {
        address stackAddress            = address(this);
        ERC20   ERC20Token              = ERC20(_tokenAddress);
        uint256 balanceBeforeTransfer   = ERC20Token.balanceOf(stackAddress);
        Stack   memory stack            = _lockedToken[msg.sender][_tokenAddress];


        require(Address.isContract(_tokenAddress), "L'addresse fournir n'est pas un contract !");
        require(dataFeeds[ERC20Token.name()].exist, "Le stacking de ce token n'est pas disponible.");

        if (stack.amount > 0)
        {
            uint256 rewardBeforeDepot = calculateReward(stack);
            stack.reward = stack.reward.add(rewardBeforeDepot);
        }

        stack.amount        = stack.amount.add(_amount);
        stack.tokenAddress  = _tokenAddress;
        stack.lastAction    = block.timestamp;
        stack.exist         = true;

        _lockedToken[msg.sender][_tokenAddress] = stack;

        if (!existToken(msg.sender, _tokenAddress))
        {
            myTokens[msg.sender].push(_tokenAddress);
        }

        ERC20Token.transferFrom(msg.sender, stackAddress, _amount);
        require(ERC20Token.balanceOf(stackAddress) == (balanceBeforeTransfer + _amount), "Le transfer du token ERC20 ne fonctionne pas !");

        emit locking(msg.sender, _tokenAddress, _amount);
    }

    function getMyBalance() external view returns(Stack[] memory)
    {
        address[]   memory mytokens = myTokens[msg.sender];
        Stack[]     memory allStack = new Stack[](mytokens.length);

        
        for (uint256 i; i < mytokens.length; i++)
        {
            allStack[i] = _lockedToken[msg.sender][mytokens[i]];
        }
        return(allStack);
    }

    function unlocked(address _tokenAddress, uint256 _amount) external nonReentrant()
    {
        ERC20   ERC20Token              = ERC20(_tokenAddress);
        uint256 balanceBeforeTransfer   = ERC20Token.balanceOf(address(this));
        Stack   memory stack            = _lockedToken[msg.sender][_tokenAddress];

        require(Address.isContract(_tokenAddress), "L'addresse fournir n'est pas un contract !");
        require(_lockedToken[msg.sender][_tokenAddress].amount >= _amount, "Le montant est superieur a votre solde");

        stack.reward        = stack.reward.add(calculateReward(stack));
        stack.lastAction    = block.timestamp;
        stack.amount        = stack.amount.sub(_amount);

        ERC20Token.transfer(msg.sender, _amount);
        require(ERC20Token.balanceOf(address(this)) == (balanceBeforeTransfer - _amount), "Le transfer du token ERC20 ne fonctionne pas !");

        emit unlocking(msg.sender, _tokenAddress, _amount);
    }


    function claimed(uint256 _amount, address _tokenAddress) external nonReentrant()
    {
        Stack memory stack  = _lockedToken[msg.sender][_tokenAddress];
        stack.reward        = stack.reward.add(calculateReward(stack));
        stack.lastAction    = block.timestamp;

        require(stack.reward >= _amount, "La demande est superieur a la recompense disponible.");
        require(fcToken.transfer(msg.sender, stack.reward), "Le transfer du token FCToken ne fonctionne pas !");

        stack.reward = stack.reward.sub(_amount);
        _lockedToken[msg.sender][_tokenAddress] = stack;

        emit claiming(msg.sender, _amount);
    }

    function existToken(address _ownerTokens, address _tokenAddress) private view returns(bool)
    {
        address[] memory mytokens = myTokens[_ownerTokens];

        for (uint256 i; i < mytokens.length; i++)
        {
            if (mytokens[i] == _tokenAddress)
            {
                return(true);
            }
        }
        return(false);
    }

    function calculateReward(Stack memory _stack) private view returns(uint256)
    {
        ERC20   ERC20Token          = ERC20(_stack.tokenAddress);    
        uint256 stackingPeriod      = block.timestamp.sub(_stack.lastAction).div(_INTEREST_PERIOD);
        uint256 interest_percentage = _INTEREST_VALUE.div(1000);
        uint256 rewardByHours       = interest_percentage * _stack.amount;
        uint256 allRewardToken      = stackingPeriod * rewardByHours;
        uint256 result              = getPrice(dataFeeds[ERC20Token.name()].dataAddress) * allRewardToken;

        return(result);
    }

    function addDataFeed(string memory _name, address _aggregator) external onlyOwner()
    {
        require(!dataFeeds[_name].exist, "Cette DataFeed existe deja.");
        
        dataFeeds[_name] = DataFeed(_aggregator, true);

        emit newDataFeed(_name, _aggregator);
    }

    function getPrice(address _aggregator) public view returns(uint256)
    {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_aggregator);

        (
            uint80 roundID, 
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();

        return uint256(price);
    }

    function getAddressFCToken() view external returns(FCToken)
    {
       return(fcToken);
    }
}