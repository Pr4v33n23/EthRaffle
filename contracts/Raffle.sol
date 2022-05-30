//Raffle
//Enter the lottery
//Pick a random winner
//Select a winner every X minutes
// Using Chainlink Oracle -> Randomness, Automated Execution (Chainlink Keeper)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

contract Raffle is VRFConsumerBaseV2 {
  /// @dev The default entrance fee in ETH i.e 0.1 ETH
  uint256 private immutable s_entranceFee;
  /// @dev To store players enterred the raffle
  address payable[] private s_players;
  /// @dev To access random function from chainlink, we are using their interface providers
  VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
  /// @dev To limit the max gas fee to pay to get VRF from chainlink
  bytes32 private immutable i_keyHash;  
  /// @dev Id of vrf consumer smart contract
  uint64 private immutable i_subscriptionId;
  /// @dev how much gas to use for the call back randomness function in the smart contract
  uint32 private immutable i_callbackGasLimit;
  /// @dev how many confirmation that chainlink needs to wait. More the number more secure the randomness
  uint16 private constant REQUEST_CONFIRMATIONS = 3;
  /// @dev number of words for randomness
  uint32 private constant NUM_WORDS = 1;


  address payable s_recentWinner;

  /// @dev To throw an error when the entrace fee entered is lower than the required amount
  error Raffle_NotEnoughETHEntered();
  error Raffle_TransferFailed();


  /// @dev To emit an event when a player enters the raffle
  event RaffleEnter(address indexed player);
  /// @dev To emit an event to request a raffer winner based on VRF randomness
  event RequestedRaffleWinner(uint256 indexed requestId);
  event WinnerPicked(address indexed recentWinner);

  constructor(address vrfCoordinatorV2, uint256 entranceFee, bytes32 keyHash, uint64 subscriptionId, uint32 callbackGasLimit)
    VRFConsumerBaseV2(vrfCoordinatorV2)
  {
    i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
    s_entranceFee = entranceFee;
    i_keyHash = keyHash;
    i_subscriptionId = subscriptionId;
    i_callbackGasLimit = callbackGasLimit;
  }

  function enterRaffle() public payable {
    if (msg.value < s_entranceFee) {
      revert Raffle_NotEnoughETHEntered();
    }
    s_players.push(payable(msg.sender));
    emit RaffleEnter(msg.sender);
  }

  function pickRandomWinner() external {
    uint256 requestId =  i_vrfCoordinator.requestRandomWords(
      i_keyHash,
      i_subscriptionId,
      REQUEST_CONFIRMATIONS,
      i_callbackGasLimit,
      NUM_WORDS
    );

    emit RequestedRaffleWinner(requestId);
  }

  function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
    internal
    override
  {
     uint256 indexOfwinner = randomWords[0] % s_players.length;
     address payable recentWinner = s_players[indexOfwinner];
     s_recentWinner = recentWinner;
     (bool success, ) = recentWinner.call{value: address(this).balance}("");
     if(!success){
       revert Raffle_TransferFailed();
     }
     emit WinnerPicked(recentWinner);
  }

  function getEntranceFee() public view returns (uint256) {
    return s_entranceFee;
  }

  function getPlayer(uint256 index) public view returns (address) {
    return s_players[index];
  }
}
