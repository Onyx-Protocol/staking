# staking - hardhat

1. Install package 
    ```
    yarn
    ``` 
    
2. Create .env file from .env.example
3. Fill value in .env file:
   1. `ACC_PRIVATE_KEY`: account deploy all contract and also set as a `admin` role. Need deposit ETH in it to deploy.
   2. `CHN_ADDRESS`: address reward token, default is CHN address.
   3. `REWARD_PER_BLOCK`: reward per block while staking contract running. It will be divided among users by weight.
   4. `START_BLOCK`: Contract staking will start in this block
   5. `MULTIPLIER`: In order to incentive user staking soon, staking contract will bonus reward from `START_BLOCK` to `END_BONUS_BLOCK`.
   6. `END_BONUS_BLOCK`: Time bonus will end in this block.
4. Compile
    ```
    yarn hardhat compile
    ```
5. Deploy + verify:
    ```
    yarn hardhat deploy --reset --tags deploy-verify  --network rinkeby
    
    ```

6. You need deposit reward into contract after deploy.