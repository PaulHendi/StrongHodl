pragma solidity ^0.6.12;

contract Router {

    function WETH() external pure returns (address) {}

	function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity) {}
    
    
     function swapExactETHForTokens(
     	uint amountOutMin, 
     	address[] calldata path, 
     	address to, 
     	uint deadline
     	) external payable returns (uint[] memory amounts) {}
    
    function swapETHForExactTokens(
     	uint amountOut,
     	address[] calldata path,
     	address to, 
     	uint deadline
     ) external payable returns (uint[] memory amounts) {}
     
     
     
    function getAmountsOut(
     	uint amountIn, 
     	address[] memory path
     ) external view  returns (uint[] memory amounts) {}

    function getAmountsIn(
     	uint amountOut, 
     	address[] memory path
     ) external view  returns (uint[] memory amounts) {}


     
   function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external view {}     
    
     
   function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external view returns (uint[] memory amounts) {}
     
  
        
     
}



