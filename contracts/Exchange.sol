// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IFactory {
      function getExchange(address _tokenAddress) external returns (address);
}

interface IExchange{
    function ethToToken(uint256 _minTokens,address recipient) external payable;
}

contract Exchange is ERC20{
    address public tokenAddress;
    address public factoryAddress; 

    constructor(address _tokenAddress) ERC20("Zuniswap-V1","ZUNI-V1"){
        require(_tokenAddress != address(0));
        tokenAddress = _tokenAddress;
        factoryAddress = msg.sender;
    }

    function addLiquidity(uint256 _tokenAmount) public payable returns(uint256){
        if(getReserve() == 0){
            IERC20 token = IERC20(tokenAddress);
            token.transferFrom(msg.sender,address(this),_tokenAmount);

            uint256 liquidity = address(this).balance;
            _mint(msg.sender,liquidity);
            return liquidity;
        }
        else{
            uint256 ethReserve = address(this).balance - msg.value;
            uint256 tokenReserve = getReserve();
            uint256 tokenAmount = msg.value*(tokenReserve/ethReserve);
            require(_tokenAmount > tokenAmount,"insufficient token amount");

            IERC20 token = IERC20(tokenAddress);
            token.transferFrom(msg.sender,address(this),_tokenAmount);

            uint256 liquidity = (totalSupply()*msg.value)/(address(this).balance);
            _mint(msg.sender,liquidity);
            return liquidity;
        }
    }

    function getReserve() public view returns(uint256){
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    function getAmount(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) private pure returns(uint256){
        require(inputReserve >0 && outputReserve>0,"Reserves cannot be 0");

        uint256 inputAmountWithFee = inputAmount*99;
        uint256 numerator = inputAmountWithFee*outputReserve;
        uint256 denominator = inputReserve*100+inputAmountWithFee;

        return (numerator)/(denominator);
    }

    function getTokenAmount(
        uint256 _ethSold
    ) public view returns(uint256){
        require(_ethSold > 0,"ethSold is too small");
         uint256 tokenReserve = getReserve();
        return getAmount(_ethSold,address(this).balance,tokenReserve);
    }

    function getEthAmount(uint256 _tokenSold) public view returns(uint256){
        require(_tokenSold > 0,"tokenSold is too small");
        uint256 tokenReserve = getReserve();
        return getAmount(_tokenSold,tokenReserve,address(this).balance);
    }

    function ethToToken(uint256 _minTokens,address recipient) public payable{
        uint256 tokenReserve = getReserve();
        uint256 tokensBought = getAmount(msg.value,address(this).balance - msg.value,tokenReserve);

        require(tokensBought >= _minTokens,"insufficient output amount");

        IERC20(tokenAddress).transfer(recipient,tokensBought);
    }

    function ethToTokenSwap(uint256 _minTokens) public payable{
        ethToToken(_minTokens,msg.sender);
    }

    function tokenToEthSwap(uint256 tokenSold,uint256 _minEth) public payable{
        uint256 tokenReserve = getReserve();
        uint256 ethBought = getAmount(tokenSold,tokenReserve - tokenSold,address(this).balance);

        require(ethBought > _minEth,"insufficient output amount");
        IERC20(tokenAddress).transferFrom(msg.sender,address(this),tokenSold);
        payable(msg.sender).transfer(ethBought);
    }

    function removeLiquidity(uint256 _amount) public returns(uint256,uint256){
        require(_amount > 0,"invalid amount");

        uint256 ethAmount = (address(this).balance*_amount)/(totalSupply());
        uint256 tokenAmount = (getReserve()*_amount)/(totalSupply());

        _burn(msg.sender,_amount);
        payable(msg.sender).transfer(ethAmount);
        IERC20(tokenAddress).transfer(msg.sender,tokenAmount);

        return (ethAmount,tokenAmount);
    }

    function TokenToTokenSwap(
        uint256 _tokensSold,
        uint256 _minTokensBought,
        address _tokenAddress
    ) public {
        address exchangeAddress = IFactory(factoryAddress).getExchange(_tokenAddress);

        require(exchangeAddress!=address(this) && exchangeAddress!=address(0),"invalid exchange address");

        uint256 tokenReserve = getReserve();
        uint256 ethBought = getAmount(_tokensSold,tokenReserve - _tokensSold,address(this).balance);

        IERC20(tokenAddress).transferFrom(
        msg.sender,
        address(this),
         _tokensSold
        );

        IExchange(exchangeAddress).ethToToken{value: ethBought}(_minTokensBought,msg.sender);
        IERC20(tokenAddress).transfer(msg.sender,_minTokensBought);
    }

}