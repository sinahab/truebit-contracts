pragma solidity ^0.4.18;

contract TaskBook {

  mapping(address => User) private users;
  mapping(uint => Task) private tasks; 
  uint jackpot = 0;
  
  // The Stages that a Task can go through.
  // Using a state machine to model the life-cycle of a Task has two benefits:
  // 1) can enforce which transitions are allowed from each state.
  // 2) can enforce state-specific time outs.
  // TODO: add states related to verification game.
  enum Stages {
    TaskCreated,
    SolverBidsCollected,
    SolverSelected,
    SolverSubmittedSolutions,
    SolverPickedSolutions,
    ChallengeBidsCollected,
    ChallengeBidsRevealed,
    ChallengerSelected
  }

  struct User {
    uint balance;
    bytes32 randomBitsHash;
  }
  
  // Used to represent a submitted challenge.
  struct Challenge {
    bytes32 numberHash;
    bytes32 solutionHash;
  }

  struct Task {
    Stages stage;
    address taskGiver;
    address[] solvers;
    address selectedSolver;
    address[] challengers;
    mapping (address => Challenge) challenges;
    uint minDeposit;
    bytes32 taskHash;
    bytes32[2] solutionHashes;
    bytes32 pickedSolutionHash;
  }

  // Create the TaskBook
  function TaskBook() public {
    return;
  }

  //------------------
  // UTILITY FUNCTIONS

  // Check balance (i.e. deposits) of a user.
  function balanceOf(address who) public constant returns (uint balance);
    return users[who].balance;
  }

  // allow user to submit a deposit.
  function submitDeposit() payable returns (bool) {
    uint balance = users[msg.sender].balance;
    users[msg.sender].balance = balance + msg.value;
    log0(sha3(msg.sender));
  }
  
  // Transition the Task's state to the next.
  function taskToNextStage(uint taskID) returns (bool) {
    Task t = tasks[taskID];
    t.stage = Stages(uint(t.stage) + 1);
  }

  //-----------------------
  // TASK LIFECYCLE

  // Task Giver creates a new Task.
  // @param bytes32 taskHash: location of the task on some filesystem (e.g. IPFS).
  // @param uint timeOut: the timeout unit which will be used for this task, denominated in number of blocks.
  // @param uint reward: Eth which TaskGiver pays (will be reduced from their existing deposits).
  // @param uint minDeposit: the minimum deposit required for participation in this Task.
  function createTask(bytes32 taskHash, uint timeOut, uint reward, uint minDeposit) returns (bool) {
    // Step 1: check if timeOut, reward, and minDeposit make sense given the task difficulty.
    // Potentially enforce minimums.

    // Step 2: check if user has enough deposits to pay for reward.
    require(users[msg.sender].balance >= reward);

    // Step 3: reduce user's by reward & increase jackpot balance by reward.

    // Step 4: create the Task.
    task = Task(Stages.TaskCreated, msg.sender, new address[](maxSolvers), 0x0, new address[](maxChallengers), minDeposit, taskHash, new bytes32[](2));
    tasks.push(task);

    // Step 5: create events to notify clients that a new Task has been created.
  }

  // Solvers bid for a Task.
  // @param uint taskID.
  // @param bytes32 _randomBitsHash: hash of random bits that Solver is committing to.
  function bidForTask(uint taskID, bytes32 _randomBitsHash) returns (bool) {
    Task t = tasks[taskID]; 
    require(t.stage == Stages.TaskCreated);
   
    // Step 1: check that user has high enough balance for minDeposit.
    balance = users[msg.sender].balance;
    require(balance >= t.minDeposit);

    // Step 2: transfer minDeposit from the user to the jackpot.
    // This will be re-debited to them if they're not picked.
    // NOTE: do safe math.
    users[msg.sender].balance = balance - minDeposit;

    // Step 3: check that _randomBitsHash has valid value.

    // Step 4: update user's randomBitsHash.
    users[msg.sender].randomBitsHash = _randomBitsHash;

    // Step 5: register users bid for becoming a Solver for the task.
    t.solvers.push(msg.sender);
  }

  // Task Giver triggers this method, which selects a Solver for the Task.
  // @param uint taskID.
  function selectSolver(uint taskID) returns (bool) {
    Task t = tasks[taskID];
   
    require(t.stage == Stages.SolverBidsCollected);

    // Can only be triggered by Task Giver. 
    require(msg.sender == t.taskGiver);

    if (t.solvers.length == 0) {
      // There are no solvers.      
      // TODO: Return Task Giver's reward.
    } else {
      t.selectedSolver = t.solvers[0];
      // TODO: refund minDeposit to all un-selected Solvers.
    }
  }

  // Solver submits both correct & incorrect solution hashes.
  // @param uint taskID.
  // @param bytes32 solutionOneHash.
  // @param bytes32 solutionTwoHash.
  function submitSolutions(uint taskID, bytes32 solutionOneHash, bytes32 solutionTwoHash) returns (bool) {
    Task t = tasks[taskID]
    
    require(t.stage == Stages.SolverSelected);

    require(msg.sender == t.solver);

    t.solutionHashes[0] = solutionOneHash;
    t.solutionHashes[1] = solutionTwoHash;
  }

  // A block has passed. The solver can now decide which solution they want to pick (because they know if there is a forced error in effect)
  // @param uint taskID.
  // @param bytes32 _pickedSolutionHash: the solution hash which the solver picks as their "correct" solution.
  function pickSolution(uint taskID, bytes32 _pickedSolutionHash) returns (bool) {
    Task t = tasks[taskID]

    require(t.stage == Stages.SolverSubmittedSolutions);
    require(msg.sender == t.solver);

    // check that _pickedSolutionHash is one of the solutions provided earlier.
    require(t.solutionHashes[0] == _pickedSolutionHash || t.solutionHashes[1] == _pickedSolutionHash);

    t.pickedSolutionHash = _pickedSolutionHash;
  }
  
  // Verifiers show whether they're interested in being challenger.
  // @param uint taskID.
  // @param bytes32 _numberHash: the hash of an integer which will be later revealed. 
  // If it is even, then the Verifier is bidding to be a challenger.
  function submitChallengeDecision(uint taskID, bytes32 _numberHash) returns (bool) {
    Task t = tasks[taskID]
    
    require(t.stage == Stages.SolverPickedSolutions);

    // Step 1: check that verifier has high enough balance for minDeposit.
    balance = users[msg.sender].balance;
    require(balance >= t.minDeposit);

    // Step 2: transfer minDeposit from the user to the jackpot.
    // This will be re-debited to them if they're not picked.
    // NOTE: do safemath.
    users[msg.sender].balance = balance - minDeposit;

    // Step 3: add verifier to list of challengers.
    t.challenges[msg.sender].numberHash = _numberHash;
  }

  // Verifiers unmask their interest in being a Challenger by "revealing" their number, and also submit their solutionHash.
  // @param uint taskID
  // @param uint number: the number whose hash was submitted in the submitChallengeDecision function.
  // @param bytes32 _solutionHash: the challenger's solution hash.
  function submitChallengeRevealed(uint taskID, uint number, bytes32 _solutionHash) returns (bool) {
    Task t = tasks[taskID];
    
    require(t.stage == Stages.ChallengeBidsCollected);

    // Register user as a challenger if number matches their previously submitted numberHash.
    if (t.challenges[msg.sender].numberHash == keccak256(number)) {
      t.challenges[msg.sender].solutionHash = _solutionHash;
      t.challengers.push = msg.sender;
    }
  }

  // selects the Challenger next up for playing the verification game with the Solver.
  // @param uint taskID. 
  function selectChallenger(uint taskID) returns (bool) {
    Task t = tasks[taskID];
    
    require(t.stage == Stages.ChallengeBidsRevealed);
   
    // Can only be triggered by Task Giver. 
    require(msg.sender == t.taskGiver);

    if (t.challengers.length == 0) {
      // Solver's solution is correct.
      // TODO: pay them a reward.
    } else {
      t.selectedChallenger = t.challengers[0];

      // NEXT:
      // depending on currect state:
      // if it's the first layer, Solver reveals their random bits (below)
      // if it's a challenge to alternate solution, goes into verification game immediately.
    }
  }

  // called by the Solver.
  // the Solver reveals their random string r to the Truebit contract. Referees check it against their commitment from the preprocessing step.
  // @param uint taskID.
  // @param bytes32 randomBits: the actual randomBits used by the Solver.
  function revealRandomBits(uint taskID, bytes32 randomBits) returns (bool) {
    // contract now knows whether there was a forced-error.
    
    // IF there is a forced-error:
    // 1. challenger & solver both get jackpot.
    // 2. the Solver's other answer is automatically picked as "correct" solution.
    // 3. the "challenge" flow (above) begins for this secondary solution.

    // ELSE there is no forced-error:
    // 1. Challenger & Solver need to play verification game.
  }

  function playVerificationGame(uint taskID) returns (bool) {
    return true;
  }
}
