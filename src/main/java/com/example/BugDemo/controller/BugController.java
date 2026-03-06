package com.example.BugDemo.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class BugController {

    @GetMapping("/divide")
    public int divide() {

        int a = 10;
        int b = 0;   // intentional bug

        return a / b;   // ArithmeticException
    }
}