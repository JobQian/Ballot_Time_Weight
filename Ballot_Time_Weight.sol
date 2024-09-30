// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

  /*
  用Solidity合约实现委托投票，以便自动和完全透明的投票计数。
  */
contract Ballot {

    uint256 public auctionStartTime; // 投票开始时间戳
    uint256 public auctionEndTime; // 投票结束时间戳

    struct Voter {
        uint256 weight;//计票的权重
        bool voted;//若为真，代表该人已投
        address delegate;//被委托人
        uint256 vote;//投票提案的索引
    }
    //提案的信息，包括名称和得票数
    struct Proposal {
        bytes32 name;//简称（最长32个字节）
        uint256 voteCount;//得票数
    }

    address public chairperson;//合约的发起人
    mapping(address => Voter) public voters;//选民信息

    //一个Proposal结构类型的动态数组，提案的动态数组
    Proposal[] public proposals;

    constructor(bytes32[] memory proposalNames,uint256 startTime,uint256 endTime) {
        //输入的结束时间必须大于开始时间
        require(endTime >= startTime, "endTime must be greater than or equal to startTime.");
        //在构造函数中初始化时间变量
        auctionStartTime = startTime;
        auctionEndTime = endTime;

        chairperson = msg.sender;
        voters[chairperson].weight = 1;

        for (uint256 i = 0; i < proposalNames.length; i++) {
            proposals.push(Proposal({name: proposalNames[i], voteCount: 0}));
        }
    }

    function giveRightToVote(address voter) external {
        require(msg.sender == chairperson, "Only chairperson can give right to vote.");
        require(!voters[voter].voted, "The voter already voted.");
        require(voters[voter].weight == 0, "The voter already has voting rights.");
        voters[voter].weight = 1;
    }

    function delegate(address to) external {
        Voter storage sender = voters[msg.sender];
        require(sender.weight != 0, "You have no right to vote.");
        require(!sender.voted, "You already voted.");
        require(to != msg.sender, "Self-delegation is disallowed.");

        while (voters[to].delegate != address(0)) {
            to = voters[to].delegate;
            require(to != msg.sender, "Found loop in delegation.");
        }

        Voter storage delegate_ = voters[to];
        require(delegate_.weight >= 1, "Selected delegate does not have voting rights.");
        sender.voted = true;
        sender.delegate = to;
        if (delegate_.voted) {
            proposals[delegate_.vote].voteCount += sender.weight;
        } else {
            delegate_.weight += sender.weight;
        }
    }

    function vote(uint256 proposal) external {
        //确保用户只能在时间窗口内投票。如果不在时间窗口内投票，抛出require错误。
        uint256 voteTime = block.timestamp;
        require(voteTime >= auctionStartTime, "voteTime must be greater than or equal to startTime.");
        require(voteTime <= auctionEndTime, "voteTime must be smaller than or equal to endTime.");

        Voter storage sender = voters[msg.sender];
        require(sender.weight != 0, "Has no right to vote.");
        require(!sender.voted, "Already voted.");
        sender.voted = true;
        sender.vote = proposal;
        proposals[proposal].voteCount += sender.weight;
    }

    function winningProposal() public view returns (uint256 winningProposal_) {
        uint256 winningVoteCount = 0;
        for (uint256 p = 0; p < proposals.length; p++) {
            if (proposals[p].voteCount > winningVoteCount) {
                winningVoteCount = proposals[p].voteCount;
                winningProposal_ = p;
            }
        }
    }

    function winnerName() external view returns (bytes32 winnerName_) {
        winnerName_ = proposals[winningProposal()].name;
    }

    function setVoterWeight (address voter, uint weight) external{
        //确保只有合约所有者（chairperson）可以调用此函数
        require(msg.sender == chairperson, "Only chairperson can set the weight of the voter.");
        //设置weight的时间，要小于等于结束时间
        uint256 setTime = block.timestamp;
        require(setTime <= auctionEndTime, "voteTime must be smaller than or equal to endTime.");
        voters[voter].weight = weight;
    }
}
