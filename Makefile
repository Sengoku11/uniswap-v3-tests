gen-uniswap-router:
	forge build -C ./node_modules/@uniswap/swap-router-contracts/contracts/interfaces/ISwapRouter02.sol
	cast interface ./out/ISwapRouter02.sol/ISwapRouter02.json -o src/ISwapRouter02.sol -n ISwapRouter02
