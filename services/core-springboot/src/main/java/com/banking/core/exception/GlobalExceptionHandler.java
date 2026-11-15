package com.banking.core.exception;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.net.URI;
import java.sql.SQLException;
import java.util.stream.Collectors;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(BankingDomainException.class)
    public ProblemDetail handleBankingDomainException(BankingDomainException ex, HttpServletRequest request) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, ex.getMessage());
        problem.setType(URI.create("https://api.banking.com/errors/domain-error"));
        problem.setTitle("Error de Negocio Bancario");
        problem.setProperty("errorCode", ex.getErrorCode());
        problem.setProperty("path", request.getRequestURI());
        return problem;
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ProblemDetail handleValidationException(MethodArgumentNotValidException ex, HttpServletRequest request) {
        String errors = ex.getBindingResult().getAllErrors().stream()
                .map(error -> {
                    String fieldName = ((FieldError) error).getField();
                    String message = error.getDefaultMessage();
                    return fieldName + ": " + message;
                })
                .collect(Collectors.joining(", "));

        ProblemDetail problem = ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, errors);
        problem.setType(URI.create("https://api.banking.com/errors/validation-error"));
        problem.setTitle("Error de Validación de Datos");
        problem.setProperty("path", request.getRequestURI());
        return problem;
    }

    @ExceptionHandler(SQLException.class)
    public ProblemDetail handleSqlException(SQLException ex, HttpServletRequest request) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(HttpStatus.INTERNAL_SERVER_ERROR, "Error interno en base de datos transaccional");
        problem.setType(URI.create("https://api.banking.com/errors/database-error"));
        problem.setTitle("Error de Base de Datos");
        problem.setProperty("sqlState", ex.getSQLState());
        problem.setProperty("errorCode", ex.getErrorCode());
        problem.setProperty("path", request.getRequestURI());
        return problem;
    }

    @ExceptionHandler(Exception.class)
    public ProblemDetail handleGenericException(Exception ex, HttpServletRequest request) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(HttpStatus.INTERNAL_SERVER_ERROR, ex.getMessage());
        problem.setType(URI.create("https://api.banking.com/errors/internal-error"));
        problem.setTitle("Error Interno del Servidor");
        problem.setProperty("path", request.getRequestURI());
        return problem;
    }
}
