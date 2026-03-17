package com.example.BugDemo.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.sql.SQLException;

@RestController
public class BugController {

    @GetMapping("/divide")
    public int divide() {
        int a = 10;
        int b = 0;   // intentional bug, unhandled
        return a / b;   // ArithmeticException
    }

    @GetMapping("/sql-error")
    public String sqlError() throws SQLException {
        throw new SQLException("Simulated SQL error: possible SQL injection detected in user input '1 OR 1=1'");
    }
}