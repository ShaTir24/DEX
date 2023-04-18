//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Exchange is ERC20 {
    address public cryptoDevTokenAddress;

    //inheriting ERC20 token as it should keep track of CryptoDev LP tokens
    constructor(address _CryptoDevtoken) ERC20("CryptoDev LP Token", "CDLP") {
        require(_CryptoDevtoken != address(0), "Token address passed is a null address");
        cryptoDevTokenAddress = _CryptoDevtoken;
    }

    //function to return the amount of CD tokens held by the contract
    function getReserve() public view returns (uint) {
        return ERC20(cryptoDevTokenAddress).balanceOf(address(this));
    }

    //function to add liquidity to the exchange
    function addLiquidity(uint _amount) public payable returns (uint) {
        uint liquidity;
        uint ethBalance = address(this).balance;
        uint cryptoDevTokenReserve = getReserve();
        ERC20 cryptoDevToken = ERC20(cryptoDevTokenAddress);

        //initially when reserves are empty, accept any amount
        if(cryptoDevTokenReserve == 0) {
            //transfer from user account to contract
            cryptoDevToken.transferFrom(msg.sender, address(this), _amount);
            //mint ethBalance amount of LP tokens to user
            //LP minted is equal to ETH transfered by user, as no ratio needs to be followed
            liquidity = ethBalance;
            _mint(msg.sender, liquidity);
        } else {
            //reserve not empty, maintain the ratio of CD token to be added to reserve
            uint ethReserve = ethBalance - msg.value;   //subtracted by the amount sent by user
            uint cryptoDevTokenAmount = (msg.value * cryptoDevTokenReserve) / (ethReserve);
            require(_amount >= cryptoDevTokenAmount, "Amount of tokens sent is less than the minimum tokens required");

            cryptoDevToken.transferFrom(msg.sender, address(this), cryptoDevTokenAmount);

            //liquidity token LP based on ratio
            liquidity = (totalSupply() * msg.value) / ethReserve;
            _mint(msg.sender, liquidity);
        }
        return liquidity;
    }

    //function to remove liquidity from the contract by withdrawing LP tokens
    function removeLiquidity(uint _amount) public returns (uint, uint) {
        require(_amount > 0, "amount should be greater than 0.");
        uint ethReserve = address(this).balance;
        uint _totalSupply = totalSupply();

        //amount to be sent back to user based on ratio
        uint ethAmount = (ethReserve * _amount) / _totalSupply;

        //amount of CD token sent back to user based on ratio
        uint cryptoDevTokenAmount = (getReserve() * _amount) / _totalSupply;

        //removing the liquidity from the contract
        _burn(msg.sender, _amount);

        //transfer ETH from contract reserve to user
        payable(msg.sender).transfer(ethAmount);

        //transfer CD token from contract reserve to user
        ERC20(cryptoDevTokenAddress).transfer(msg.sender, cryptoDevTokenAmount);
        return (ethAmount, cryptoDevTokenAmount);
    }

    //function to return the amount of ETH/CD token in return of swapping the token
    function getAmountOfTokens(
        uint inputAmount, 
        uint inputReserve,
        uint outputReserve
    ) public pure returns (uint) {
        require(inputReserve > 0 && outputReserve > 0, "Invalid Reserves");

        //charging 1% fee
        uint inputAmountWithFee = inputAmount * 99;

        //acc. to formula del.y = (y * del.x) / (x + del.x)
        //del.y is token to be received
        //del.x is input amount after deducting charges
        //x = inputReserve, y = outputReserve

        uint numerator = inputAmountWithFee * outputReserve;
        uint denominator = (inputReserve * 100) + inputAmountWithFee;
        return numerator / denominator;
    }

    //function performing swaps between ETH and CDtoken
    function ethToCrytpoDevToken(uint _minTokens) public payable {
        uint tokenReserve = getReserve();
        //calling the above method to get CD token 
        //inputReserve is passed as address(this).balance - msg.sender because
        //to get the actual input reserve
        uint tokensBought = getAmountOfTokens(msg.value, address(this).balance - msg.value, tokenReserve);

        require(tokensBought >= _minTokens, "Insufficient output amount");

        //transferring CD tokens to the user
        ERC20(cryptoDevTokenAddress).transfer(msg.sender, tokensBought);
    }

    function cryptoDevTokenToEth(uint _tokensSold, uint _minEth) public {
        uint tokenReserve = getReserve();
        uint ethBought = getAmountOfTokens(_tokensSold, tokenReserve, address(this).balance);

        require(ethBought >= _minEth, "Insufficient output amount");

        //transfer CD tokens from user's address to contract address
        ERC20(cryptoDevTokenAddress).transferFrom(msg.sender, address(this), _tokensSold);

        //sending ethBought from contract to user
        payable(msg.sender).transfer(ethBought);
    }
}