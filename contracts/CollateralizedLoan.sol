// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CollateralizedLoan {
    struct Loan {
        address payable borrower;
        address payable lender;
        uint256 collateralAmount;
        uint256 loanAmount;
        uint256 interestRate; // In basis points (1% = 100)
        uint256 dueDate;
        bool isActive;
        bool isFunded;
        bool isRepaid;
    }

    mapping(uint256 => Loan) public loans;
    uint256 public nextLoanId;

    // Events
    event LoanRequested(
        uint256 indexed loanId,
        address indexed borrower,
        uint256 collateralAmount,
        uint256 loanAmount,
        uint256 interestRate,
        uint256 dueDate
    );

    event LoanFunded(uint256 indexed loanId, address indexed lender);
    event LoanRepaid(uint256 indexed loanId);
    event CollateralClaimed(uint256 indexed loanId, address indexed lender);
    event CollateralReturned(uint256 indexed loanId, address indexed borrower);

    // Modifiers
    modifier loanExists(uint256 loanId) {
        require(loans[loanId].borrower != address(0), "Loan does not exist");
        _;
    }

    modifier onlyBorrower(uint256 loanId) {
        require(msg.sender == loans[loanId].borrower, "Only borrower can call this");
        _;
    }

    modifier onlyLender(uint256 loanId) {
        require(msg.sender == loans[loanId].lender, "Only lender can call this");
        _;
    }

    modifier loanNotFunded(uint256 loanId) {
        require(!loans[loanId].isFunded, "Loan is already funded");
        _;
    }

    modifier loanFunded(uint256 loanId) {
        require(loans[loanId].isFunded, "Loan is not funded");
        _;
    }

    modifier loanNotRepaid(uint256 loanId) {
        require(!loans[loanId].isRepaid, "Loan is already repaid");
        _;
    }

    function requestLoan(
        uint256 interestRate,
        uint256 durationInDays
    ) external payable returns (uint256) {
        require(msg.value > 0, "Collateral amount must be greater than 0");
        require(interestRate > 0, "Interest rate must be greater than 0");
        require(durationInDays > 0, "Duration must be greater than 0");

        uint256 loanId = nextLoanId++;
        uint256 dueDate = block.timestamp + (durationInDays * 1 days);

        loans[loanId] = Loan({
            borrower: payable(msg.sender),
            lender: payable(address(0)),
            collateralAmount: msg.value,
            loanAmount: msg.value,
            interestRate: interestRate,
            dueDate: dueDate,
            isActive: true,
            isFunded: false,
            isRepaid: false
        });

        emit LoanRequested(
            loanId,
            msg.sender,
            msg.value,
            msg.value,
            interestRate,
            dueDate
        );

        return loanId;
    }

    function fundLoan(uint256 loanId) 
        external 
        payable
        loanExists(loanId)
        loanNotFunded(loanId)
    {
        Loan storage loan = loans[loanId];
        require(msg.value == loan.loanAmount, "Must send exact loan amount");
        require(block.timestamp < loan.dueDate, "Loan has expired");
        loan.lender = payable(msg.sender);
        loan.isFunded = true;

        // Transfer loan amount to borrower
        (bool sent, ) = loan.borrower.call{value: msg.value}("");
        require(sent, "Failed to send loan amount to borrower");

        emit LoanFunded(loanId, msg.sender);
    }

    function repayLoan(uint256 loanId) 
        external 
        payable
        loanExists(loanId)
        loanFunded(loanId)
        loanNotRepaid(loanId)
    {
        Loan storage loan = loans[loanId];
        require(block.timestamp <= loan.dueDate, "Loan has expired");

        uint256 interest = (loan.loanAmount * loan.interestRate) / 10000;
        uint256 totalRepayment = loan.loanAmount + interest;
        require(msg.value >= totalRepayment, "Insufficient repayment amount");

        loan.isRepaid = true;
        loan.isActive = false;

        // Transfer repayment to lender
        (bool sentToLender, ) = loan.lender.call{value: totalRepayment}("");
        require(sentToLender, "Failed to send repayment to lender");

        // Return collateral to borrower
        (bool sentToBorrower, ) = loan.borrower.call{value: loan.collateralAmount}("");
        require(sentToBorrower, "Failed to return collateral to borrower");

        emit LoanRepaid(loanId);
        emit CollateralReturned(loanId, loan.borrower);
    }

    function claimCollateral(uint256 loanId)
        external
        loanExists(loanId)
        loanFunded(loanId)
        loanNotRepaid(loanId)
        onlyLender(loanId)
    {
        Loan storage loan = loans[loanId];
        require(block.timestamp > loan.dueDate, "Loan is not yet defaulted");

        loan.isActive = false;
        
        // Transfer collateral to lender
        (bool sent, ) = loan.lender.call{value: loan.collateralAmount}("");
        require(sent, "Failed to transfer collateral to lender");

        emit CollateralClaimed(loanId, loan.lender);
    }

    function getLoan(uint256 loanId) external view returns (
        address borrower,
        address lender,
        uint256 collateralAmount,
        uint256 loanAmount,
        uint256 interestRate,
        uint256 dueDate,
        bool isActive,
        bool isFunded,
        bool isRepaid
    ) {
        Loan storage loan = loans[loanId];
        return (
            loan.borrower,
            loan.lender,
            loan.collateralAmount,
            loan.loanAmount,
            loan.interestRate,
            loan.dueDate,
            loan.isActive,
            loan.isFunded,
            loan.isRepaid
        );
    }
}