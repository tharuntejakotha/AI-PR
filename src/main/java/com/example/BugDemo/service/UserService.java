package com.example.BugDemo.service;

public class UserService {

    public String getUser(String username){

        String query = "SELECT * FROM users WHERE name = '" + username + "'";

        return query;
    }
}