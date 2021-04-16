pragma solidity ^0.6.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract Governance {
    address public _governance;

    constructor() public {
        _governance = tx.origin;
    }

    event GovernanceTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    modifier onlyGovernance {
        require(msg.sender == _governance, "not governance");
        _;
    }

    function setGovernance(address governance) public onlyGovernance {
        require(governance != address(0), "new governance the zero address");
        emit GovernanceTransferred(_governance, governance);
        _governance = governance;
    }
}

pragma experimental ABIEncoderV2;

interface IFairLaunch {
    struct UserInfo {
        uint256 amount; // How many Staking tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        address fundedBy; // Funded by who?
        //
        // We do some fancy math here. Basically, any point in time, the amount of CODEXs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accCodexPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws Staking tokens to a pool. Here's what happens:
        //   1. The pool's `accCodexPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    function userInfo(uint256 _pid, address _user)
        external
        view
        returns (UserInfo memory);
}

contract Voting is Governance, Context {
    using SafeMath for uint256;

    uint256 public constant DURATION_VOTING = 10 days;
    uint256 public endVoting = 0;
    uint256 public totalVotingPool = 0;
    bool public isStarted = false;

    struct VotingPool {
        address poolFarmAddress;
        uint256 poolFarmPid;
        address fairLaunchAddress;
        uint256 fairLaunchPid;
        address stakeToken;
        address votingToken;
        uint256 weight;
    }

    mapping(uint256 => VotingPool) votingPools;
    mapping(uint256 => address[]) votingAddresses;
    mapping(uint256 => mapping(address => bool)) isVoted;

    constructor() public {
        _governance = _msgSender();
    }

    function startVoting() public onlyGovernance {
        require(!isStarted, "Voting is started");
        endVoting = now.add(DURATION_VOTING);

        isStarted = true;
    }

    function stopVoting() public onlyGovernance {
        require(isStarted, "Voting is not started");
        require(endVoting < now, "Voting is not end");

        for (uint256 index = 0; index < totalVotingPool; index++) {
            uint256 vId = index.add(1);
            uint256 votingWeight = 0;
            address[] memory listVoters = votingAddresses[vId];
            for (
                uint256 indexAddress = 0;
                indexAddress < listVoters.length;
                indexAddress++
            ) {
                votingWeight = votingWeight.add(
                    getWeight(listVoters[indexAddress], vId)
                );
            }
            votingPools[vId].weight = votingWeight;
        }
    }

    modifier inVotingTime {
        require(endVoting >= now, "Overtime voting");
        _;
    }

    function addVoting(
        address _poolFarmAddress,
        uint256 _poolFarmPid,
        address _stakeToken,
        address _votingToken,
        address _fairLaunchAddress,
        uint256 _fairLaunchPid
    ) public onlyGovernance {
        VotingPool memory votingPool =
            VotingPool({
                poolFarmAddress: _poolFarmAddress,
                poolFarmPid: _poolFarmPid,
                fairLaunchAddress: _fairLaunchAddress,
                fairLaunchPid: _fairLaunchPid,
                stakeToken: _stakeToken,
                votingToken: _votingToken,
                weight: 0
            });

        totalVotingPool++;
        votingPools[totalVotingPool] = votingPool;
    }

    function getWeight(address you, uint256 vId)
        public
        view
        returns (uint256 weight)
    {
        VotingPool memory votingPool = votingPools[vId];
        uint256 yourBalance = IERC20(votingPool.votingToken).balanceOf(you);
        uint256 yourStaked =
            IFairLaunch(votingPool.fairLaunchAddress)
                .userInfo(votingPool.fairLaunchPid, you)
                .amount;

        weight = yourBalance.add(yourStaked);
    }

    function vote(uint256 vId) external inVotingTime {
        require(!isVoted[vId][_msgSender()], "Already voted");
        require(vId <= totalVotingPool, "Voting pool is not exists");

        votingAddresses[vId].push(_msgSender());
        isVoted[vId][_msgSender()] = true;
    }
}
