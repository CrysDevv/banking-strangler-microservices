package com.banking.core.exception;

public class BankingDomainException extends RuntimeException {
    private final int errorCode;

    public BankingDomainException(int errorCode, String message) {
        super(message);
        this.errorCode = errorCode;
    }

    public int getErrorCode() {
        return errorCode;
    }
}
