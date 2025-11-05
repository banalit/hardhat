// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract MockAggregatorV3 is AggregatorV3Interface {
    int256 public answer; // 模拟的价格数据
    uint8 public decimals; // 价格小数位
    uint256 public updatedAt; // 最后更新时间

    constructor(int256 _answer, uint8 _decimals) {
        answer = _answer;
        decimals = _decimals;
        updatedAt = block.timestamp;
    }

    // 修复 getRoundData：确保 answerInRound > roundId
    function getRoundData(uint80 _roundId) external view returns (
        uint80 roundId,
        int256 answer_,
        uint256 startedAt,
        uint256 updatedAt_,
        uint80 answerInRound
    ) {
        roundId = _roundId;
        answer_ = answer;
        updatedAt_ = updatedAt;
        answerInRound = _roundId + 1; // 确保 answerInRound > roundId
        return (roundId, answer_, 0, updatedAt_, answerInRound);
    }

    // 修复 latestRoundData：使用 currentRoundId，确保 answerInRound > roundId
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer_,
        uint256 startedAt,
        uint256 updatedAt_,
        uint80 answerInRound
    ) {
        uint80 currentRoundId = 1; // 模拟当前轮次 ID
        roundId = currentRoundId;
        answer_ = answer;
        updatedAt_ = updatedAt;
        answerInRound = currentRoundId + 1; // 最新轮次的答案在 roundId + 1 中，满足 > roundId
        return (roundId, answer_, 0, updatedAt_, answerInRound);
    }

    // 实现接口其他方法（返回默认值）
    function description() external view returns (string memory) {
        return "Mock Price Feed";
    }

    function version() external view returns (uint256) {
        return 1;
    }

    // 新增：方便测试中更新价格
    function setAnswer(int256 _answer) external {
        answer = _answer;
    }
}