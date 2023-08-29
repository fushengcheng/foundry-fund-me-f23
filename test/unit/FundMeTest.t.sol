// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    address USER = makeAddr("user"); //foundry std lib中定义的方法，仅用于测试。
    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant GAS_PRICE = 1;

    function setUp() external {
        //fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, STARTING_BALANCE); //给账户增加一定的以太，这也是个cheat code，仅用于foundry中的测试。
    }

    function testMinimumDollarIsFive() public {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public {
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert(); //foundry cheatcode, 期望下一条指令会revert，如果revert了，测试通过，如果没有revert，反而测试失败。
        fundMe.fund(); //没有传入ETH，所以会revert，测试通过。若想传入ETH，可以用fundMe.fund{value: 10}();
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.prank(USER); //The next TX will be sent by USER.
        fundMe.fund{value: SEND_VALUE}(); //这条交易将由USER发送。
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.expectRevert();
        vm.prank(USER);
        fundMe.withdraw();
    }

    function testWithDrawWithASingleFunder() public funded {
        //Arrange 安排,一般就是获取测试要用的到状态初值；
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        //Act 执行，一般就是执行测试操作，修改相应的状态；
        //vm.txGasPrice(GAS_PRICE); //anvil链上默认Gas Price为0，可以通过这个cheat code设置Gas Price。
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        //Assert 断言，判断执行测试操作后的状态是否正确。
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(
            startingFundMeBalance + startingOwnerBalance,
            endingOwnerBalance
        );
    }

    function testWithdrawFromMultipleFunders() public funded {
        //Arrange
        uint160 numberOfFunders = 10; //使用uint160是因为之后要直接用数字作为地址，只有uint160可以直接转换为address。
        uint160 startingFunderIndex = 1; //不从0开始是因为一般会禁止使用0地址，且会做一些检查。
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE); //foundry标准库中的方法，相当于vm.prank加vm.deal。
            fundMe.fund{value: SEND_VALUE}();
        }
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        //Act
        vm.startPrank(fundMe.getOwner()); //在start和stop之间的Tx都将会使用指定地址发送
        fundMe.withdraw();
        vm.stopPrank();

        //Assert
        //uint256 endingOwnerBalance = fundMe.getOwner().balance;
        //uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(address(fundMe).balance, 0);
        assertEq(
            startingFundMeBalance + startingOwnerBalance,
            fundMe.getOwner().balance
        );
    }

    function testWithdrawFromMultipleFundersCheaper() public funded {
        //Arrange
        uint160 numberOfFunders = 10; //使用uint160是因为之后要直接用数字作为地址，只有uint160可以直接转换为address。
        uint160 startingFunderIndex = 1; //不从0开始是因为一般会禁止使用0地址，且会做一些检查。
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE); //foundry标准库中的方法，相当于vm.prank加vm.deal。
            fundMe.fund{value: SEND_VALUE}();
        }
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        //Act
        vm.startPrank(fundMe.getOwner()); //在start和stop之间的Tx都将会使用指定地址发送
        fundMe.cheaperWithdraw();
        vm.stopPrank();

        //Assert
        //uint256 endingOwnerBalance = fundMe.getOwner().balance;
        //uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(address(fundMe).balance, 0);
        assertEq(
            startingFundMeBalance + startingOwnerBalance,
            fundMe.getOwner().balance
        );
    }
}
