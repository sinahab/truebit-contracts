pragma solidity ^0.4.4;

import './AccountManager.sol';

contract TaskBook is AccountManager {

	uint private numTasks = 0;
	uint constant maxSolvers = 10;
	uint constant maxChallengers = 10;

	event TaskCreated(uint taskID, uint minDeposit, uint blockNumber);
	event SolverSelected(uint indexed taskID, address solver, bytes32 taskData, uint minDeposit);
	event SolutionCommitted(uint taskID, uint minDeposit, bytes32 taskData, address solver);

	mapping(uint => Task) private tasks;
	mapping(address => mapping(uint => bytes32)) private solverRandomBitsHash;
	mapping(address => mapping(uint => bytes32)) private solutions;
	mapping(address => mapping(uint => bytes32)) private verifierIntent;

	struct Task {
		address owner;
		address[] solvers;
		address selectedSolver;
		uint minDeposit;
		bytes32 taskData;
		uint numSolvers;
		address[] challengers;
		uint numChallengers;
	}

	//Task Issuers create tasks to be solved
	function createTask(uint minDeposit, bytes32 taskData, uint numBlocks) returns (bool) {
		require(balances[msg.sender] >= minDeposit);
		tasks[numTasks] = Task(msg.sender, new address[](maxSolvers), 0x0, minDeposit, taskData, 0, new address[](maxChallengers), 0);
		log0(sha3(msg.sender));//possible bug if log is after event
		TaskCreated(numTasks, minDeposit, block.number+numBlocks);
		numTasks++;
		return true;
	}

	//Solver registers for tasks
	function registerForTask(uint taskID, uint minDeposit, bytes32 randomBitsHash) returns(bool) {
		require(balances[msg.sender] >= minDeposit);
		Task t = tasks[taskID];
		require(!(t.owner == 0x0));
		require(t.numSolvers < maxSolvers);
		solverRandomBitsHash[msg.sender][taskID] = randomBitsHash;
		//random = sha3(random, block.blockhash(block.number-1));
		t.solvers[t.numSolvers] = msg.sender;
		t.numSolvers++;
		log0(bytes32(sha3(msg.sender)));
		return true;
	}

	//Task Issuer tells TrueBitExchange to select a solver
	function selectSolver(uint taskID) returns (bool) {
		Task t = tasks[taskID];
		require(msg.sender == t.owner);
		//uint random = uint(block.blockhash(block.number-1));
		//address randomSolver = t.solvers[uint(random) % t.numSolvers];
		address solver = t.solvers[0];
		t.selectedSolver = solver;
		SolverSelected(taskID, solver, t.taskData, t.minDeposit);
		return true;
	}

	//Selected solver submits a solution to the exchange
	function commitSolution(uint taskID, bytes32 solutionHash) returns (bool) {
		Task t = tasks[taskID];
		require(t.selectedSolver == msg.sender);
		solutions[msg.sender][taskID] = solutionHash;
		SolutionCommitted(taskID, t.minDeposit, t.taskData, msg.sender);
		return true;
	}

	//Verifier submits a challenge to the solution provided for a task
	function commitChallenge(uint taskID, uint minDeposit, address solver, bytes32 intentHash) returns (bool) {
		require(balances[msg.sender] >= minDeposit);
		require(!(solutions[solver][taskID] == 0x0));
		Task t = tasks[taskID];
		require(t.numChallengers < maxChallengers);
		verifierIntent[msg.sender][taskID] = intentHash;
		t.challengers.push(msg.sender);
		log0(sha3(msg.sender));
		return true;
	}
}