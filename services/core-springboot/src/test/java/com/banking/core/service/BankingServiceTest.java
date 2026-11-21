package com.banking.core.service;

import org.junit.jupiter.api.Test;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class BankingServiceTest {

    @Test
    void parsesSqlServerUniqueIdentifierReturnedAsString() throws SQLException {
        UUID expected = UUID.fromString("6b394bf8-9d82-4c8f-a12a-d9ba9d89bd8f");
        ResultSet resultSet = mock(ResultSet.class);
        when(resultSet.getString("TransferenciaId")).thenReturn(expected.toString());

        assertEquals(expected, BankingService.readUniqueIdentifier(resultSet, "TransferenciaId"));
    }

    @Test
    void returnsNullForMovementWithoutTransferId() throws SQLException {
        ResultSet resultSet = mock(ResultSet.class);
        when(resultSet.getString("TransferenciaId")).thenReturn(null);

        assertNull(BankingService.readUniqueIdentifier(resultSet, "TransferenciaId"));
    }
}
