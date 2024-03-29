// SPDX-License-Identifier: MIT
pragma solidity =0.8.10;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Staking is ERC1155Holder, ReentrancyGuard, Ownable {
    IERC1155 public nftToken;
    IERC20 public erc20Token;

    uint256 public tokensPerBlock; // the amount of tokens rewarded per block staked
    uint256 public totalNFTsStaked; // the total amount of NFTs that have been staked to the contract
    uint256 public maxReward;

    bool public paused;

    struct Stake {
        address owner;
        uint256 stakedFromBlock;
    }

    // TokenID => Stake
    mapping(uint256 => Stake) public receipt;
    // Mapping from the owner (Staker) to an array of all the token IDs they've staked
    mapping(address => uint256[]) public stakedNFTs;
    // Add ability for user to keep track of all claimed rewards
    mapping(address => uint256) public pastClaims;

    mapping(uint256 => uint256) public claimedPerNft;

    event NFTStaked(
        address indexed staker,
        uint256 tokenId,
        uint256 blockNumber
    );
    event NFTUnStaked(
        address indexed staker,
        uint256 tokenId,
        uint256 blockNumber
    );
    event StakePayout(
        address indexed staker,
        uint256 tokenId,
        uint256 stakeAmount,
        uint256 fromBlock,
        uint256 toBlock
    );
    event StakeRewardUpdated(uint256 rewardPerBlock);

    // Sets the smart contract addresses for the NFT & ERC20 contract, as well as the amount
    // of rewards per block will be given to users that stake their NFTs
    constructor(
        address _nftToken,
        address _erc20Token,
        uint256 _tokensPerBlock,
        uint256 _maxReward
    ) {
        nftToken = IERC1155(_nftToken);
        erc20Token = IERC20(_erc20Token);
        tokensPerBlock = _tokensPerBlock;
        paused = false;
        maxReward = _maxReward;

        emit StakeRewardUpdated(tokensPerBlock);
    }

    // Requires that only the NFT smart contract can call certain functions
    modifier onlyNFT() {
        require(
            msg.sender == address(nftToken),
            "Stake: Caller can only be the ERC1155 contract"
        );
        _;
    }

    // Returns the total amount of ERC20 tokens that this contract owns
    function getStakeContractBalance() public view returns (uint256) {
        return erc20Token.balanceOf(address(this));
    }

    // Allows you to set a new ERC20 contract address
    function setERC20Contract(address _tokenAddress) public onlyOwner {
        erc20Token = IERC20(_tokenAddress);
    }

    // Allows you to set a new NFT contract address
    function setNFTContract(address _nftAddress) public onlyOwner {
        nftToken = IERC1155(_nftAddress);
    }

    // Allows you to update the rewards per block amount
    function updateStakingReward(uint256 _tokensPerBlock) external onlyOwner {
        tokensPerBlock = _tokensPerBlock;
        emit StakeRewardUpdated(tokensPerBlock);
    }

    // Returns the length of the total amount an account has staked to this smart contract
    function totalNFTsUserStaked(address account)
        public
        view
        returns (uint256)
    {
        return stakedNFTs[account].length;
    }

    // This contract gets called by the NFT contract when a user transfers its
    // NFT to it. It will only allow the NFT contract to call it and will log their
    // address and info to properly pay them out.
    // Whenever they want to unstake they call this contract directly which
    // will then transfer the funds and NFTs to them
    function stakeNFT(address from, uint256 tokenId) external onlyNFT {
        // Checks to make sure this contract received the NFT.
        require(paused == false, "Staking is paused");
        require(
            nftToken.balanceOf(address(this), tokenId) == 1,
            "Stake: Token Transfer Failed"
        );

        receipt[tokenId].owner = from;
        receipt[tokenId].stakedFromBlock = block.number;
        stakedNFTs[from].push(tokenId);
        totalNFTsStaked++;

        emit NFTStaked(from, tokenId, block.number);
    }

    // NOTE: Due to the unavoidable gas limit of the Ethereum network,
    // a large amount of NFTs transfered could result to a failed transaction.
    // @dev This function NEEDS to be called from the NFT smart contract. Can't
    // be called directly or else it will fail. Allows a user to stake multiple
    // NFTs. The Parameters are fed by the NFT contract
    function stakeMultipleNFTs(address from, uint256[] calldata tokenIds)
        external
        onlyNFT
    {
        require(paused == false, "Staking is paused");
        for (uint256 i; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i]; // gas saver
            // Checks to make sure this contract received the NFT.
            require(
                nftToken.balanceOf(address(this), tokenId) == 1,
                "Stake: Token Transfer Failed"
            );

            receipt[tokenId].owner = from;
            receipt[tokenId].stakedFromBlock = block.number;
            stakedNFTs[from].push(tokenId);

            emit NFTStaked(from, tokenId, block.number);
        }
        totalNFTsStaked += tokenIds.length;
    }

    // This is the function a user calls when they want to unstake a single NFT.
    // Can be called directly, does not have to be called from the NFT contract.
    function unstakeNFT(uint256 tokenId) external nonReentrant {
        _onlyStaker(tokenId);
        _requireTimeElapsed(tokenId);
        _payoutStake(tokenId);

        uint256[] memory _stakedNFTs = stakedNFTs[msg.sender]; // gas saver
        for (uint256 i; i < _stakedNFTs.length; i++) {
            if (_stakedNFTs[i] == tokenId) {
                stakedNFTs[msg.sender][i] = _stakedNFTs[_stakedNFTs.length - 1];
                stakedNFTs[msg.sender].pop();
            }
        }
        nftToken.safeTransferFrom(address(this), msg.sender, tokenId, 1, "");
        totalNFTsStaked--;
    }

    // This is the function to call when a user wants to unstake multiple NFTs.
    // Can be called directly. The user has to pass in an array of all the NFTs
    // they would like to unstake.
    function unstakeMultipleNFTs(uint256[] calldata tokenIds)
        external
        nonReentrant
    {
        // Array needed to pay out the NFTs
        uint256[] memory amounts = new uint256[](tokenIds.length);
        uint256[] storage _stakedNFTs = stakedNFTs[msg.sender]; // gas saver

        for (uint256 i; i < tokenIds.length; i++) {
            uint256 id = tokenIds[i]; // gas saver

            _onlyStaker(id);
            _requireTimeElapsed(id);
            _payoutStake(id);
            amounts[i] = 1;

            // Finds the ID in the array and removes it.
            for (uint256 x; x < _stakedNFTs.length; x++) {
                if (id == _stakedNFTs[x]) {
                    _stakedNFTs[x] = _stakedNFTs[_stakedNFTs.length - 1];
                    _stakedNFTs.pop();
                    break;
                }
            }

            emit NFTUnStaked(msg.sender, id, receipt[id].stakedFromBlock);
        }

        nftToken.safeBatchTransferFrom(
            address(this),
            msg.sender,
            tokenIds,
            amounts,
            ""
        );
        totalNFTsStaked -= tokenIds.length;
    }

    // This function is called when a user wants to withdraw their funds without
    // unstaking their NFT
    function withdrawRewards(uint256[] calldata tokenIds)
        external
        nonReentrant
    {
        for (uint256 i; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i]; // gas saver
            _onlyStaker(tokenId);
            _requireTimeElapsed(tokenId);
            _payoutStake(tokenId);

            // update receipt with a new block number
            receipt[tokenId].stakedFromBlock = block.number;
        }
    }

    // Withdraws rewards from all NFTs staked without passing in an array of specific
    // token IDs from which you want to withdraw from
    // NOTE: Cheaper on gas to pass in the array of tokenIDs rather than not
    // but by not passing the array in it can withdraw everything while the other can
    // specify only the NFT rewards you'd like to withdraw from.
    function withdrawRewardsNoArray() external nonReentrant {
        uint256[] memory _stakedNFTs = stakedNFTs[msg.sender]; // gas saver
        for (uint256 i; i < _stakedNFTs.length; i++) {
            uint256 tokenId = _stakedNFTs[i];
            _onlyStaker(tokenId);
            _requireTimeElapsed(tokenId);
            _payoutStake(tokenId);

            // update receipt with a new block number
            receipt[tokenId].stakedFromBlock = block.number;
        }
    }

    // NOTE: To only be called by a nonReentrant function.
    // This function is meant to be called by other functions within the smart contract.
    // Never called externally by the client.
    function _payoutStake(uint256 tokenId) private {
        Stake memory _tokenId = receipt[tokenId]; // gas saver

        // earned amount is difference between the stake start block, current block multiplied by stake amount
        uint256 timeStaked = (block.number - _tokenId.stakedFromBlock) - 1; // don't pay for the tx block of withdrawl
        uint256 payout = timeStaked * tokensPerBlock;

        if (payout + claimedPerNft[tokenId] >= maxReward) {
            payout = maxReward - claimedPerNft[tokenId];
        } else if (claimedPerNft[tokenId] >= maxReward) {
            payout = 0;
        }

        // If contract does not have enough tokens to pay out, return the NFT without payment
        // This prevent a NFT being locked in the contract when empty
        if (erc20Token.balanceOf(address(this)) < payout) {
            emit StakePayout(
                msg.sender,
                tokenId,
                0,
                _tokenId.stakedFromBlock,
                block.number
            );
        } else {
            // payout stake
            erc20Token.transfer(_tokenId.owner, payout);
            pastClaims[_tokenId.owner] += payout;
            claimedPerNft[tokenId] += payout;
            emit StakePayout(
                msg.sender,
                tokenId,
                payout,
                _tokenId.stakedFromBlock,
                block.number
            );
        }
    }

    // Checks that only the person that staked the NFT can call a certain function
    function _onlyStaker(uint256 tokenId) private view {
        // require that this contract has the NFT
        require(
            nftToken.balanceOf(address(this), tokenId) == 1,
            "onlyStaker: Contract is not owner of this NFT"
        );

        // require that this token is staked
        require(
            receipt[tokenId].stakedFromBlock != 0,
            "onlyStaker: Token is not staked"
        );

        // require that msg.sender is the owner of this nft
        require(
            receipt[tokenId].owner == msg.sender,
            "onlyStaker: Caller is not NFT stake owner"
        );
    }

    // Requires that some time has elapsed (IE you can NOT stake and unstake in the same block)
    function _requireTimeElapsed(uint256 tokenId) private view {
        require(
            receipt[tokenId].stakedFromBlock < block.number,
            "requireTimeElapsed: Can not stake/unStake/harvest in same block"
        );
    }

    // Returns an array of all the NFTs a user has staked
    function getAllNFTsUserStaked(address account)
        public
        view
        returns (uint256[] memory)
    {
        return stakedNFTs[account];
    }

    function _getTimeStaked(uint256 tokenId) internal view returns (uint256) {
        if (receipt[tokenId].stakedFromBlock == 0) {
            return 0;
        }
        return receipt[tokenId].stakedFromBlock;
    }

    function _getCurrentStakeEarned(uint256 tokenId)
        public
        view
        returns (uint256)
    {
        uint256 total;
        if (receipt[tokenId].stakedFromBlock == 0) {
            return 0;
        }

        if (
            (((block.number - _getTimeStaked(tokenId)) * tokensPerBlock) +
                claimedPerNft[tokenId]) <= maxReward
        ) {
            total = (block.number - _getTimeStaked(tokenId)) * tokensPerBlock;
        } else if (
            (((block.number - _getTimeStaked(tokenId)) * tokensPerBlock) +
                claimedPerNft[tokenId]) >= maxReward
        ) {
            total = maxReward - claimedPerNft[tokenId];
        }
        return total;
    }

    function getPendingRewards(address _user) public view returns (uint256) {
        if (paused) {
            return 0;
        }
        uint256 total = 0;
        uint256[] memory _stakedNFTs = stakedNFTs[_user];
        for (uint256 i; i < _stakedNFTs.length; i++) {
            uint256 tokenId = _stakedNFTs[i];
            total += _getCurrentStakeEarned(tokenId);
        }
        return total;
    }

    function getPastClaims() public view returns (uint256) {
        return pastClaims[msg.sender];
    }

    function setPause(bool _paused) public onlyOwner {
        paused = _paused;
    }

    function withdrawAndEnd() public onlyOwner {
        setPause(true);
        erc20Token.transfer(msg.sender, erc20Token.balanceOf(address(this)));
    }
}
