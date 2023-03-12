const strongHODL = artifacts.require("strongHODL");
const Pair = artifacts.require('Pair.sol');
const Router = artifacts.require('Router.sol');

contract("Simulation", async accounts => {


	
	
    it("Adding liquidity (After DxSale)", async () => {
    
    const owner = accounts[0];
   
    
    const strongHODLToken = await strongHODL.deployed();
    // Pancakeswap V2 router 
    const router = await Router.at('0xD99D1c33F9fC3444f8101754aBC46c52416550D1'); 
    // Main Net : 0x10ED43C718714eb63d5aA57B78B54704E256024E
    // Test Net : 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3     
    
    // SHP/WBNB pair was defined in the contract => Getting the address
    const pair_address = await strongHODLToken.getPairAddress.call();  
    const pair = await Pair.at(pair_address);
    
    // Get the balance
    let balance = await pair.balanceOf(owner); 
    console.log(`balance LP: ${balance.toString()}`);  
				
    // Owner adds liquidity => Need to approve
    await strongHODLToken.approve.sendTransaction(router.address, "1000000000000000000000",
    							{
						            from: owner,
						            gas: 4000000,
          						});
        
    console.log('erc20 approved');       
        
   
    
    // Owner adds liquidity 10BNB, 10*10 token
	await router.addLiquidityETH(
      				strongHODLToken.address,
			        "1000000000000000000000",
		            "1000000000000000000000",
	                "10000000000000000000", 
			        owner,
			        Math.floor(Date.now() / 1000) + 1000000 * 60,
			        {
			            from: owner,
			            gas: 4000000,
            			value: "10000000000000000000"
      				});
     console.log('liquidity added');
        
      
    // Get the balance of LP of the owner
    balance = await pair.balanceOf(owner); 
    console.log(`balance LP: ${balance.toString()}`); 
              
       
    });
    
    
    async function buySHP(buyer, tokenAmount, SHP) {
    
    	
    // Main Net : 0x10ED43C718714eb63d5aA57B78B54704E256024E
    // Test Net : 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3     
	    const router = await Router.at('0xD99D1c33F9fC3444f8101754aBC46c52416550D1'); 
	    var path = new Array(2);
	    // Main Net : 0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c
	    // Test Net : 0x094616f0bdfb0b526bd735bf66eca0ad254ca81f
        path[0] = await router.WETH(); // WBNB 
        path[1] = SHP.address;
	    
	    
	    var amounts = await router.getAmountsIn.call(tokenAmount, path);
		var necessaryBNB = parseInt(amounts[0].valueOf()).toString();
	    
	    
		console.log(`Input BNB : ${necessaryBNB}`);  
		console.log(`Output token : ${tokenAmount}`);      	
        
		await router.swapETHForExactTokens(
			tokenAmount,
	        path,
            buyer,
            Math.floor(Date.now() / 1000) + 60 * 10, {
            	from: buyer,
            	value: necessaryBNB
            });    
    
    }    
    
    
    
    
        

       
              
    async function sellSHP(seller, tokenAmount, SHP) {
    
    	
    // Main Net : 0x10ED43C718714eb63d5aA57B78B54704E256024E
    // Test Net : 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3     
	    const router = await Router.at('0xD99D1c33F9fC3444f8101754aBC46c52416550D1'); 
	    var path = new Array(2);
	    // Main Net : 0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c
	    // Test Net : 0x094616f0bdfb0b526bd735bf66eca0ad254ca81f
        path[0] = SHP.address;
        path[1] = await router.WETH(); // WBNB 

	    
	    // Check path order
	    
	    // Check below
	    var amounts = await router.getAmountsOut.call(tokenAmount, path);
		var outBNB = parseInt(amounts[1].valueOf()).toString();
		
		//console.log(`Input token : ${tokenAmount}`);  
		//console.log(`Output BNB : ${outBNB}`);  
	    
	    
	    // Seller adds liquidity => Need to approve
    	await SHP.approve.sendTransaction(router.address, tokenAmount,
    							{
						            from: seller,
						            gas: 6000000
          						});
        
    	console.log('bep20 approved');   
	    
    	
        // Check necessity of passing from
		await router.swapExactTokensForETHSupportingFeeOnTransferTokens(
			tokenAmount,
			0,
	        path,
            seller,
            Math.floor(Date.now() / 1000) + 60 * 10,
    							{
						            from: seller,
						            gas: 6000000						          
          						});    
    
    
    }
    
    
    
    it("Greg buys SHP", async () => {
        
        const strongHODLToken = await strongHODL.deployed();    
    	const greg = accounts[1];
 
		
		balance = await strongHODLToken.balanceOf.call(greg);
		console.log(`Balance of greg before : ${parseInt(balance.valueOf()).toString()}`); 
		
		


		var SHP_to_buy = "10000000000000000";
		await buySHP(greg, SHP_to_buy, strongHODLToken);
		
    		

		balance = await strongHODLToken.balanceOf.call(greg);
		console.log(`Balance of greg after : ${parseInt(balance.valueOf()).toString()}`);  
    });
    
                 
    
    
     it("Greg sells SHP", async () => {
        
        const strongHODLToken = await strongHODL.deployed();    
		const greg = accounts[1];

 
		
		balance = await strongHODLToken.balanceOf.call(greg);
		console.log(`Balance of greg before : ${parseInt(balance.valueOf()).toString()}`); 
		var SHP_to_sell = "3000000000000";

		
		
    // Main Net : 0x10ED43C718714eb63d5aA57B78B54704E256024E
    // Test Net : 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3     
	    const router = await Router.at('0xD99D1c33F9fC3444f8101754aBC46c52416550D1'); 
	    var path = new Array(2);
	    // Main Net : 0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c
	    // Test Net : 0x094616f0bdfb0b526bd735bf66eca0ad254ca81f
        path[0] = strongHODLToken.address;
        path[1] = await router.WETH(); // WBNB 

	    
	    // Check path order
	    
	    // Check below
	    var amounts = await router.getAmountsOut.call(SHP_to_sell, path);
		var outBNB = parseInt(amounts[1].valueOf()).toString();
		
		//console.log(`Input token : ${tokenAmount}`);  
		//console.log(`Output BNB : ${outBNB}`);  
	    
	    
	    // Seller adds liquidity => Need to approve
    	await strongHODLToken.approve.sendTransaction(router.address, SHP_to_sell,
    							{
						            from: greg,
						            gas: 6000000
          						});

    	console.log('bep20 approved');   
    	
    	
    	var allowances = await strongHODLToken.allowance.call(greg, router.address);
 	    console.log(`Allowances : ${parseInt(allowances.valueOf()).toString()}`);   
	    
    	
        // Check necessity of passing from
		await router.swapExactTokensForETHSupportingFeeOnTransferTokens(
			SHP_to_sell,
			0,
	        path,
            greg,
            Math.floor(Date.now() / 1000) + 60 * 10, {from:greg, gas:6000000});    
          						
          								
		
		//await sellSHP(greg, SHP_to_sell, strongHODLToken);
		balance = await strongHODLToken.balanceOf.call(greg);
		console.log(`Balance of greg after : ${parseInt(balance.valueOf()).toString()}`); 
	 
    });    
    
            
    
    
    
    
    
    
});

